import Auth
import Combine
import Foundation
import OSLog
import Supabase

@MainActor
final class CloudSyncManager: ObservableObject {
    @Published private(set) var isReady = false

    private let store: ExpenseJournalStore
    private let languageManager: LanguageManager
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.djdonkeykong.notely", category: "cloud-sync")
    private var cancellables = Set<AnyCancellable>()
    private var activeUserID: UUID?
    private var hasCompletedInitialSync = false
    private var isBootstrapping = false
    private var isApplyingRemoteState = false
    private var pendingUploadTask: Task<Void, Never>?
    private var pendingLocalTrackedCategories: Set<ExpenseCategory>? = nil

    init(
        store: ExpenseJournalStore,
        languageManager: LanguageManager,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.languageManager = languageManager
        self.defaults = defaults
        observeLocalChanges()
    }

    func refreshAuthenticationState(
        isReady: Bool,
        isAuthenticated: Bool
    ) async {
        guard isReady else {
            self.isReady = false
            return
        }

        guard isAuthenticated else {
            pendingUploadTask?.cancel()
            pendingUploadTask = nil
            activeUserID = nil
            hasCompletedInitialSync = false
            store.resetForSignOut()
            self.isReady = true
            return
        }

        let session: Session
        do {
            if let currentSession = SupabaseService.client.auth.currentSession {
                session = currentSession
            } else {
                session = try await SupabaseService.client.auth.session
            }
        } catch {
            logger.error("Could not recover Supabase session: \(error.localizedDescription, privacy: .public)")
            self.isReady = true
            return
        }

        if activeUserID == session.user.id, hasCompletedInitialSync {
            self.isReady = true
            return
        }

        self.isReady = false

        do {
            isBootstrapping = true
            try await bootstrap(for: session.user)
            isBootstrapping = false
            activeUserID = session.user.id
            hasCompletedInitialSync = true

            // pendingLocalTrackedCategories was already applied inside apply() to
            // prevent the user's in-flight category change from being overwritten.
            pendingLocalTrackedCategories = nil

            // Upload FCM token now that we have a confirmed authenticated user
            FCMTokenManager.shared.uploadCurrentTokenIfAvailable()

            // Reschedule smart notifications now that store data is up to date
            await NotificationContentEngine.shared.reschedule(store: store)

            await pushLatestLocalStateIfPossible()
        } catch {
            isBootstrapping = false
            pendingLocalTrackedCategories = nil
            logger.error("Initial cloud sync failed: \(error.localizedDescription, privacy: .public)")
        }

        self.isReady = true
    }

    private func observeLocalChanges() {
        Publishers.CombineLatest4(
            store.$entries,
            store.$budgetPlan,
            store.$trackedCategories,
            store.$recurringTransactions
        )
            .sink { [weak self] _, _, _, _ in
                self?.scheduleUpload()
            }
            .store(in: &cancellables)

        store.$customCategories
            .sink { [weak self] _ in self?.scheduleUpload() }
            .store(in: &cancellables)

        // Capture category changes that happen while bootstrap is fetching remote data.
        // bootstrap()'s apply() overwrites local state; this lets us restore the user's
        // intent after bootstrap completes.
        store.$trackedCategories
            .sink { [weak self] categories in
                guard let self else { return }
                if self.isBootstrapping, !self.isApplyingRemoteState {
                    self.pendingLocalTrackedCategories = categories
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .sink { [weak self] _ in
                self?.scheduleUpload()
            }
            .store(in: &cancellables)
    }

    private func bootstrap(for user: User) async throws {
        let remoteState = try await SupabaseFinanceService.fetchFinanceState(userID: user.id)
        let shouldBootstrapLocalOnboarding = PendingOnboardingBootstrap.shouldBootstrap(defaults: defaults)

        // A freshly created backend user can already have default preferences
        // such as currency_code without having any real finance state yet.
        // When onboarding has just completed locally, prefer that local snapshot
        // unless the server already has substantive finance data.
        if shouldBootstrapLocalOnboarding, !remoteState.hasPersistedFinanceData {
            try await pushSnapshot(
                makeLocalSnapshot(markingOnboardingComplete: true),
                user: user
            )
            PendingOnboardingBootstrap.clear(defaults: defaults)

            let refreshedRemoteState = try await SupabaseFinanceService.fetchFinanceState(userID: user.id)
            apply(remoteState: refreshedRemoteState)
            return
        }

        if remoteState.hasServerData {
            PendingOnboardingBootstrap.clear(defaults: defaults)
            // Merge any local entries that were created but not yet pushed before
            // the app closed. Without this, entries whose upload debounce hadn't
            // fired are silently wiped by replaceAll().
            let mergedState = remoteState.merging(localOnlyEntries: store.entries)
            apply(remoteState: mergedState)
            try await backfillMissingProfilePreferencesIfNeeded(
                remoteState: remoteState,
                user: user
            )
            return
        }

        PendingOnboardingBootstrap.clear(defaults: defaults)
        apply(remoteState: .empty(userID: user.id))
    }

    private func backfillMissingProfilePreferencesIfNeeded(
        remoteState: RemoteFinanceState,
        user: User
    ) async throws {
        let localSnapshot = makeLocalSnapshot()
        let needsCurrencyBackfill = remoteState.user.currencyCode == nil
        let needsLanguageBackfill = remoteState.user.languageCode == nil

        guard needsCurrencyBackfill || needsLanguageBackfill else {
            return
        }

        try await SupabaseFinanceService.upsertProfilePreferences(
            userID: user.id,
            email: user.email,
            displayName: resolvedDisplayName(for: user),
            currencyCode: needsCurrencyBackfill
                ? localSnapshot.currencyCode
                : (remoteState.user.currencyCode ?? localSnapshot.currencyCode),
            languageCode: needsLanguageBackfill
                ? localSnapshot.languageCode
                : (remoteState.user.languageCode ?? localSnapshot.languageCode)
        )
    }

    private func scheduleUpload() {
        guard activeUserID != nil, hasCompletedInitialSync, !isApplyingRemoteState else {
            return
        }

        pendingUploadTask?.cancel()
        pendingUploadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self else { return }
            await self.pushLatestLocalStateIfPossible()
        }
    }

    private func pushLatestLocalStateIfPossible() async {
        guard
            let activeUserID,
            let user = currentAuthenticatedUser(),
            user.id == activeUserID,
            hasCompletedInitialSync,
            !isApplyingRemoteState
        else {
            return
        }

        do {
            try await pushSnapshot(
                makeLocalSnapshot(),
                user: user
            )
        } catch {
            logger.error("Cloud upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pushSnapshot(
        _ snapshot: LocalFinanceSnapshot,
        user: User
    ) async throws {
        try await SupabaseFinanceService.replaceFinanceState(
            snapshot,
            userID: user.id,
            email: user.email,
            displayName: resolvedDisplayName(for: user)
        )
    }

    private func apply(remoteState: RemoteFinanceState) {
        isApplyingRemoteState = true

        if let languageCode = remoteState.user.languageCode {
            defaults.set(languageCode, forKey: NotyfiLocale.languageStorageKey)
            NotyfiSharedStorage.sharedDefaults().set(languageCode, forKey: NotyfiLocale.languageStorageKey)
            languageManager.applyStoredPreference()
        }

        let budgetPlan = remoteState.budgetPlan
        // Prefer pending local categories if the user changed them while bootstrap was
        // fetching remote data; this prevents a visible overwrite-then-restore flicker.
        let trackedCategories = pendingLocalTrackedCategories ?? remoteState.trackedCategories
        let entries = remoteState.entries
        let recurringTransactions = remoteState.recurringTransactions

        store.replaceAll(
            entries: entries,
            budgetPlan: budgetPlan,
            trackedCategories: trackedCategories,
            recurringTransactions: recurringTransactions,
            customCategories: remoteState.customCategories
        )

        if let currencyCode = remoteState.user.currencyCode,
           let preference = NotyfiCurrency.preference(for: currencyCode) {
            defaults.set(preference.rawValue, forKey: NotyfiCurrency.storageKey)
        }

        if remoteState.user.onboardingCompletedAt != nil {
            defaults.set(true, forKey: PendingOnboardingBootstrap.onboardingCompletedKey)
        }

        isApplyingRemoteState = false

        if store.materializeDueRecurringEntries(upTo: Date()) {
            scheduleUpload()
        }
    }

    private func makeLocalSnapshot(markingOnboardingComplete: Bool = false) -> LocalFinanceSnapshot {
        LocalFinanceSnapshot(
            entries: store.entries,
            budgetPlan: store.budgetPlan,
            trackedCategories: store.trackedCategories,
            recurringTransactions: store.recurringTransactions,
            customCategories: store.customCategories,
            currencyCode: NotyfiCurrency.currentCode(defaults: defaults),
            languageCode: NotyfiLocale.storedLanguageCode(defaults: defaults),
            onboardingCompleted: markingOnboardingComplete
                || defaults.bool(forKey: PendingOnboardingBootstrap.onboardingCompletedKey)
        )
    }

    private func currentAuthenticatedUser() -> User? {
        SupabaseService.client.auth.currentSession?.user
    }

    private func resolvedDisplayName(for user: User) -> String? {
        user.userMetadata["full_name"]?.stringValue
            ?? user.userMetadata["name"]?.stringValue
    }
}

enum PendingOnboardingBootstrap {
    static let key = "notyfi.supabase.pending-onboarding-bootstrap"
    static let onboardingCompletedKey = "notyfi.onboarding.complete"

    static func markPending(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func shouldBootstrap(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }
}

private struct LocalFinanceSnapshot {
    let entries: [ExpenseEntry]
    let budgetPlan: BudgetPlan
    let trackedCategories: Set<ExpenseCategory>
    let recurringTransactions: [RecurringTransaction]
    let customCategories: [CustomCategoryDefinition]
    let currencyCode: String
    let languageCode: String
    let onboardingCompleted: Bool
}

private struct RemoteFinanceState {
    let user: UserProfileRow
    let activePlan: BudgetPlanRow?
    let categoryTargets: [BudgetCategoryTargetRow]
    let recurringTransactions: [RecurringTransaction]
    let entries: [ExpenseEntry]
    let customCategories: [CustomCategoryDefinition]

    var hasPersistedFinanceData: Bool {
        user.onboardingCompletedAt != nil
            || user.monthlyBudget != nil
            || activePlan != nil
            || !categoryTargets.isEmpty
            || !recurringTransactions.isEmpty
            || !entries.isEmpty
    }

    var hasServerData: Bool {
        hasPersistedFinanceData
            || user.currencyCode != nil
            || user.languageCode != nil
    }

    var budgetPlan: BudgetPlan {
        var categoryTargetValues = categoryTargets.compactMap { row -> BudgetCategoryTarget? in
            guard !row.category.isEmpty else { return nil }
            return BudgetCategoryTarget(
                category: ExpenseCategory(rawValue: row.category),
                amount: row.targetAmount
            )
        }

        categoryTargetValues.sort { lhs, rhs in
            lhs.category.title < rhs.category.title
        }

        return BudgetPlan(
            monthlySpendingLimit: activePlan?.monthlyLimit ?? user.monthlyBudget ?? 0,
            monthlySavingsTarget: activePlan?.monthlySavingsTarget ?? 0,
            categoryTargets: categoryTargetValues
        )
    }

    var trackedCategories: Set<ExpenseCategory> {
        Set(categoryTargets.compactMap { row -> ExpenseCategory? in
            guard !row.category.isEmpty else { return nil }
            return ExpenseCategory(rawValue: row.category)
        })
    }

    static func empty(userID: UUID) -> RemoteFinanceState {
        RemoteFinanceState(
            user: UserProfileRow(id: userID, email: nil, displayName: nil, currencyCode: nil, languageCode: nil, monthlyBudget: nil, onboardingCompletedAt: nil),
            activePlan: nil,
            categoryTargets: [],
            recurringTransactions: [],
            entries: [],
            customCategories: []
        )
    }

    func merging(localOnlyEntries: [ExpenseEntry]) -> RemoteFinanceState {
        let remoteIDs = Set(entries.map(\.id))
        let unpushed = localOnlyEntries.filter { !remoteIDs.contains($0.id) }
        guard !unpushed.isEmpty else { return self }
        return RemoteFinanceState(
            user: user,
            activePlan: activePlan,
            categoryTargets: categoryTargets,
            recurringTransactions: recurringTransactions,
            entries: entries + unpushed,
            customCategories: customCategories
        )
    }
}

private enum SupabaseFinanceService {
    static func fetchFinanceState(userID: UUID) async throws -> RemoteFinanceState {
        async let userRows: [UserProfileRow] = SupabaseService.client
            .from("users")
            .select()
            .eq("id", value: userID.uuidString.lowercased())
            .execute()
            .value

        async let activePlanRows: [BudgetPlanRow] = SupabaseService.client
            .from("budget_plans")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .eq("is_active", value: true)
            .execute()
            .value

        async let customCategoryRows: [CustomCategoryRow] = SupabaseService.client
            .from("custom_categories")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        async let entryRows: [ExpenseEntryRow] = SupabaseService.client
            .from("expense_entries")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        async let recurringRows: [RecurringTransactionRow] = SupabaseService.client
            .from("recurring_transactions")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let fetchedUserRows = try await userRows
        let fetchedActivePlanRows = try await activePlanRows
        let fetchedEntryRows = try await entryRows
        let fetchedRecurringRows = try await recurringRows
        let fetchedCustomCategoryRows = try await customCategoryRows

        let user = fetchedUserRows.first
            ?? UserProfileRow(
                id: userID,
                email: nil,
                displayName: nil,
                currencyCode: nil,
                languageCode: nil,
                monthlyBudget: nil,
                onboardingCompletedAt: nil
            )
        let activePlan = fetchedActivePlanRows.first
        let entries = fetchedEntryRows.map(\.asExpenseEntry)
        let recurringTransactions = fetchedRecurringRows.map(\.asRecurringTransaction)
        let customCategories = fetchedCustomCategoryRows.map(\.asDefinition)

        let categoryTargets: [BudgetCategoryTargetRow]
        if let activePlan {
            categoryTargets = try await SupabaseService.client
                .from("budget_category_targets")
                .select()
                .eq("plan_id", value: activePlan.id.uuidString.lowercased())
                .eq("user_id", value: userID.uuidString.lowercased())
                .execute()
                .value
        } else {
            categoryTargets = []
        }

        return RemoteFinanceState(
            user: user,
            activePlan: activePlan,
            categoryTargets: categoryTargets,
            recurringTransactions: recurringTransactions.sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }

                return lhs.nextOccurrenceAt < rhs.nextOccurrenceAt
            },
            entries: entries.sorted { lhs, rhs in
                if Calendar.current.isDate(lhs.date, equalTo: rhs.date, toGranularity: .day) {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.date > rhs.date
            },
            customCategories: customCategories
        )
    }

    static func replaceFinanceState(
        _ snapshot: LocalFinanceSnapshot,
        userID: UUID,
        email: String?,
        displayName: String?
    ) async throws {
        try await upsertUserProfile(
            snapshot,
            userID: userID,
            email: email,
            displayName: displayName
        )

        let activePlanID = try await upsertBudgetPlan(
            snapshot,
            userID: userID
        )

        try await replaceCategoryTargets(
            snapshot,
            userID: userID,
            activePlanID: activePlanID
        )

        try await replaceRecurringTransactions(
            snapshot.recurringTransactions,
            userID: userID
        )

        try await replaceExpenseEntries(
            snapshot.entries,
            userID: userID
        )

        try await replaceCustomCategories(
            snapshot.customCategories,
            userID: userID
        )
    }

    private static func replaceCustomCategories(
        _ categories: [CustomCategoryDefinition],
        userID: UUID
    ) async throws {
        if !categories.isEmpty {
            let payload = categories.map { CustomCategoryPayload(definition: $0, userID: userID) }
            try await SupabaseService.client
                .from("custom_categories")
                .upsert(payload, onConflict: "user_id,raw_value")
                .execute()
        }

        let existingRows: [CustomCategoryRawValueRow] = try await SupabaseService.client
            .from("custom_categories")
            .select("raw_value")
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let localRawValues = Set(categories.map(\.rawValue))
        let staleRawValues = existingRows.map(\.rawValue).filter { !localRawValues.contains($0) }

        for stale in staleRawValues {
            try await SupabaseService.client
                .from("custom_categories")
                .delete()
                .eq("user_id", value: userID.uuidString.lowercased())
                .eq("raw_value", value: stale)
                .execute()
        }
    }

    private static func replaceRecurringTransactions(
        _ recurringTransactions: [RecurringTransaction],
        userID: UUID
    ) async throws {
        if !recurringTransactions.isEmpty {
            let payload = recurringTransactions.map {
                RecurringTransactionPayload(
                    recurringTransaction: $0,
                    userID: userID
                )
            }

            try await SupabaseService.client
                .from("recurring_transactions")
                .upsert(payload, onConflict: "id")
                .execute()
        }

        let existingRows: [RecurringTransactionIdentifierRow] = try await SupabaseService.client
            .from("recurring_transactions")
            .select("id")
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let localRecurringIDs = Set(recurringTransactions.map(\.id))
        let staleRecurringIDs = existingRows
            .map(\.id)
            .filter { !localRecurringIDs.contains($0) }

        for staleRecurringID in staleRecurringIDs {
            try await SupabaseService.client
                .from("recurring_transactions")
                .delete()
                .eq("id", value: staleRecurringID.uuidString.lowercased())
                .eq("user_id", value: userID.uuidString.lowercased())
                .execute()
        }
    }

    static func upsertProfilePreferences(
        userID: UUID,
        email: String?,
        displayName: String?,
        currencyCode: String,
        languageCode: String
    ) async throws {
        let payload = UserPreferencePayload(
            id: userID,
            email: email,
            displayName: displayName,
            currencyCode: currencyCode,
            languageCode: languageCode
        )

        try await SupabaseService.client
            .from("users")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    private static func upsertUserProfile(
        _ snapshot: LocalFinanceSnapshot,
        userID: UUID,
        email: String?,
        displayName: String?
    ) async throws {
        let payload = UserProfilePayload(
            id: userID,
            email: email,
            displayName: displayName,
            currencyCode: snapshot.currencyCode,
            languageCode: snapshot.languageCode,
            monthlyBudget: snapshot.budgetPlan.monthlySpendingLimit > 0 ? snapshot.budgetPlan.monthlySpendingLimit : nil,
            onboardingCompletedAt: snapshot.onboardingCompleted ? Date() : nil
        )

        try await SupabaseService.client
            .from("users")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    private static func upsertBudgetPlan(
        _ snapshot: LocalFinanceSnapshot,
        userID: UUID
    ) async throws -> UUID {
        let existingPlans: [BudgetPlanRow] = try await SupabaseService.client
            .from("budget_plans")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .eq("is_active", value: true)
            .execute()
            .value

        let activePlanID = existingPlans.first?.id ?? UUID()
        let payload = BudgetPlanPayload(
            id: activePlanID,
            userID: userID,
            monthlyLimit: snapshot.budgetPlan.monthlySpendingLimit,
            monthlySavingsTarget: snapshot.budgetPlan.monthlySavingsTarget,
            currencyCode: snapshot.currencyCode,
            isActive: true
        )

        try await SupabaseService.client
            .from("budget_plans")
            .upsert(payload, onConflict: "id")
            .execute()

        return activePlanID
    }

    private static func replaceCategoryTargets(
        _ snapshot: LocalFinanceSnapshot,
        userID: UUID,
        activePlanID: UUID
    ) async throws {
        let selectedCategories = snapshot.trackedCategories.sorted {
            $0.rawValue < $1.rawValue
        }

        if selectedCategories.isEmpty {
            try await SupabaseService.client
                .from("budget_category_targets")
                .delete()
                .eq("plan_id", value: activePlanID.uuidString.lowercased())
                .eq("user_id", value: userID.uuidString.lowercased())
                .execute()
            return
        }

        let payload = selectedCategories.map { category in
            BudgetCategoryTargetPayload(
                planID: activePlanID,
                userID: userID,
                category: category.rawValue,
                targetAmount: snapshot.budgetPlan.target(for: category)
            )
        }

        try await SupabaseService.client
            .from("budget_category_targets")
            .upsert(payload, onConflict: "plan_id,category")
            .execute()

        let existingRows: [BudgetCategoryTargetRow] = try await SupabaseService.client
            .from("budget_category_targets")
            .select()
            .eq("plan_id", value: activePlanID.uuidString.lowercased())
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let selectedCategoryRawValues = Set(selectedCategories.map(\.rawValue))
        let staleCategories = existingRows
            .map(\.category)
            .filter { !selectedCategoryRawValues.contains($0) }

        for staleCategory in staleCategories {
            try await SupabaseService.client
                .from("budget_category_targets")
                .delete()
                .eq("plan_id", value: activePlanID.uuidString.lowercased())
                .eq("user_id", value: userID.uuidString.lowercased())
                .eq("category", value: staleCategory)
                .execute()
        }
    }

    private static func replaceExpenseEntries(
        _ entries: [ExpenseEntry],
        userID: UUID
    ) async throws {
        if !entries.isEmpty {
            let payload = entries.map { ExpenseEntryPayload(entry: $0, userID: userID) }
            try await SupabaseService.client
                .from("expense_entries")
                .upsert(payload, onConflict: "id")
                .execute()
        }

        let existingRows: [ExpenseEntryIdentifierRow] = try await SupabaseService.client
            .from("expense_entries")
            .select("id")
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let localEntryIDs = Set(entries.map(\.id))
        let staleEntryIDs = existingRows
            .map(\.id)
            .filter { !localEntryIDs.contains($0) }

        for staleEntryID in staleEntryIDs {
            try await SupabaseService.client
                .from("expense_entries")
                .delete()
                .eq("id", value: staleEntryID.uuidString.lowercased())
                .eq("user_id", value: userID.uuidString.lowercased())
                .execute()
        }
    }
}

private struct UserProfileRow: Decodable {
    let id: UUID
    let email: String?
    let displayName: String?
    let currencyCode: String?
    let languageCode: String?
    let monthlyBudget: Double?
    let onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case currencyCode = "currency_code"
        case languageCode = "language_code"
        case monthlyBudget = "monthly_budget"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

private struct BudgetPlanRow: Decodable {
    let id: UUID
    let userID: UUID
    let monthlyLimit: Double
    let monthlySavingsTarget: Double
    let currencyCode: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case monthlyLimit = "monthly_limit"
        case monthlySavingsTarget = "monthly_savings_target"
        case currencyCode = "currency_code"
        case isActive = "is_active"
    }
}

private struct BudgetCategoryTargetRow: Decodable {
    let planID: UUID
    let userID: UUID
    let category: String
    let targetAmount: Double

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case userID = "user_id"
        case category
        case targetAmount = "target_amount"
    }
}

private struct ExpenseEntryRow: Decodable {
    let id: UUID
    let userID: UUID
    let rawText: String?
    let title: String?
    let amount: Double
    let currencyCode: String
    let category: String?
    let merchant: String?
    let note: String?
    let entryType: String
    let confidence: String
    let isAmountEstimated: Bool
    let occurredAt: Date
    let createdAt: Date
    let recurringTransactionID: UUID?
    let recurrenceInstanceKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case rawText = "raw_text"
        case title
        case amount
        case currencyCode = "currency_code"
        case category
        case merchant
        case note
        case entryType = "entry_type"
        case confidence
        case isAmountEstimated = "is_amount_estimated"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case recurringTransactionID = "recurring_transaction_id"
        case recurrenceInstanceKey = "recurrence_instance_key"
    }

    var asExpenseEntry: ExpenseEntry {
        ExpenseEntry(
            id: id,
            rawText: rawText ?? title ?? "",
            title: title ?? rawText ?? "Untitled entry".notyfiLocalized,
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: TransactionKind(rawValue: entryType) ?? .expense,
            category: ExpenseCategory(rawValue: category ?? "uncategorized"),
            merchant: merchant,
            date: occurredAt,
            note: note ?? "",
            confidence: ParsingConfidence(rawValue: confidence) ?? .review,
            isAmountEstimated: isAmountEstimated,
            createdAt: createdAt,
            recurringTransactionID: recurringTransactionID,
            recurrenceInstanceKey: recurrenceInstanceKey
        )
    }
}

private struct ExpenseEntryIdentifierRow: Decodable {
    let id: UUID
}

private struct RecurringTransactionRow: Decodable {
    let id: UUID
    let userID: UUID
    let title: String
    let rawTextTemplate: String
    let amount: Double
    let currencyCode: String
    let transactionKind: String
    let category: String
    let merchant: String?
    let note: String
    let frequency: String
    let interval: Int
    let startsAt: Date
    let nextOccurrenceAt: Date
    let endsAt: Date?
    let isActive: Bool
    let autopost: Bool
    let lastGeneratedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case rawTextTemplate = "raw_text_template"
        case amount
        case currencyCode = "currency_code"
        case transactionKind = "transaction_kind"
        case category
        case merchant
        case note
        case frequency
        case interval
        case startsAt = "starts_at"
        case nextOccurrenceAt = "next_occurrence_at"
        case endsAt = "ends_at"
        case isActive = "is_active"
        case autopost
        case lastGeneratedAt = "last_generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var asRecurringTransaction: RecurringTransaction {
        RecurringTransaction(
            id: id,
            title: title,
            rawTextTemplate: rawTextTemplate,
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: TransactionKind(rawValue: transactionKind) ?? .expense,
            category: ExpenseCategory(rawValue: category),
            merchant: merchant,
            note: note,
            frequency: RecurringFrequency(rawValue: frequency) ?? .monthly,
            interval: interval,
            startsAt: startsAt,
            nextOccurrenceAt: nextOccurrenceAt,
            endsAt: endsAt,
            isActive: isActive,
            autopost: autopost,
            lastGeneratedAt: lastGeneratedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct RecurringTransactionIdentifierRow: Decodable {
    let id: UUID
}

private struct UserProfilePayload: Encodable {
    let id: UUID
    let email: String?
    let displayName: String?
    let currencyCode: String
    let languageCode: String
    let monthlyBudget: Double?
    let onboardingCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case currencyCode = "currency_code"
        case languageCode = "language_code"
        case monthlyBudget = "monthly_budget"
        case onboardingCompletedAt = "onboarding_completed_at"
    }
}

private struct UserPreferencePayload: Encodable {
    let id: UUID
    let email: String?
    let displayName: String?
    let currencyCode: String
    let languageCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case currencyCode = "currency_code"
        case languageCode = "language_code"
    }
}

private struct BudgetPlanPayload: Encodable {
    let id: UUID
    let userID: UUID
    let monthlyLimit: Double
    let monthlySavingsTarget: Double
    let currencyCode: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case monthlyLimit = "monthly_limit"
        case monthlySavingsTarget = "monthly_savings_target"
        case currencyCode = "currency_code"
        case isActive = "is_active"
    }
}

private struct BudgetCategoryTargetPayload: Encodable {
    let planID: UUID
    let userID: UUID
    let category: String
    let targetAmount: Double

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case userID = "user_id"
        case category
        case targetAmount = "target_amount"
    }
}

private struct ExpenseEntryPayload: Encodable {
    let id: UUID
    let userID: UUID
    let rawText: String
    let title: String
    let amount: Double
    let currencyCode: String
    let category: String
    let merchant: String?
    let note: String
    let entryType: String
    let confidence: String
    let isAmountEstimated: Bool
    let entryDate: String
    let occurredAt: Date
    let createdAt: Date
    let recurringTransactionID: UUID?
    let recurrenceInstanceKey: String?

    init(entry: ExpenseEntry, userID: UUID) {
        self.id = entry.id
        self.userID = userID
        self.rawText = entry.rawText
        self.title = entry.title
        self.amount = entry.amount
        self.currencyCode = entry.currencyCode
        self.category = entry.category.rawValue
        self.merchant = entry.merchant
        self.note = entry.note
        self.entryType = entry.transactionKind.rawValue
        self.confidence = entry.confidence.rawValue
        self.isAmountEstimated = entry.isAmountEstimated
        self.entryDate = Self.entryDateFormatter.string(from: entry.date)
        self.occurredAt = entry.date
        self.createdAt = entry.createdAt
        self.recurringTransactionID = entry.recurringTransactionID
        self.recurrenceInstanceKey = entry.recurrenceInstanceKey
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case rawText = "raw_text"
        case title
        case amount
        case currencyCode = "currency_code"
        case category
        case merchant
        case note
        case entryType = "entry_type"
        case confidence
        case isAmountEstimated = "is_amount_estimated"
        case entryDate = "entry_date"
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case recurringTransactionID = "recurring_transaction_id"
        case recurrenceInstanceKey = "recurrence_instance_key"
    }

    private static let entryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct CustomCategoryRow: Decodable {
    let userID: UUID
    let rawValue: String
    let title: String
    let symbol: String
    let tintR: Double
    let tintG: Double
    let tintB: Double

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case rawValue = "raw_value"
        case title
        case symbol
        case tintR = "tint_r"
        case tintG = "tint_g"
        case tintB = "tint_b"
    }

    var asDefinition: CustomCategoryDefinition {
        CustomCategoryDefinition(
            rawValue: rawValue, title: title, symbol: symbol,
            tintR: tintR, tintG: tintG, tintB: tintB
        )
    }
}

private struct CustomCategoryRawValueRow: Decodable {
    let rawValue: String
    enum CodingKeys: String, CodingKey { case rawValue = "raw_value" }
}

private struct CustomCategoryPayload: Encodable {
    let userID: UUID
    let rawValue: String
    let title: String
    let symbol: String
    let tintR: Double
    let tintG: Double
    let tintB: Double

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case rawValue = "raw_value"
        case title
        case symbol
        case tintR = "tint_r"
        case tintG = "tint_g"
        case tintB = "tint_b"
    }

    init(definition: CustomCategoryDefinition, userID: UUID) {
        self.userID = userID
        self.rawValue = definition.rawValue
        self.title = definition.title
        self.symbol = definition.symbol
        self.tintR = definition.tintR
        self.tintG = definition.tintG
        self.tintB = definition.tintB
    }
}

private struct RecurringTransactionPayload: Encodable {
    let id: UUID
    let userID: UUID
    let title: String
    let rawTextTemplate: String
    let amount: Double
    let currencyCode: String
    let transactionKind: String
    let category: String
    let merchant: String?
    let note: String
    let frequency: String
    let interval: Int
    let startsAt: Date
    let nextOccurrenceAt: Date
    let endsAt: Date?
    let isActive: Bool
    let autopost: Bool
    let lastGeneratedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    init(recurringTransaction: RecurringTransaction, userID: UUID) {
        self.id = recurringTransaction.id
        self.userID = userID
        self.title = recurringTransaction.title
        self.rawTextTemplate = recurringTransaction.rawTextTemplate
        self.amount = recurringTransaction.amount
        self.currencyCode = recurringTransaction.currencyCode
        self.transactionKind = recurringTransaction.transactionKind.rawValue
        self.category = recurringTransaction.category.rawValue
        self.merchant = recurringTransaction.merchant
        self.note = recurringTransaction.note
        self.frequency = recurringTransaction.frequency.rawValue
        self.interval = recurringTransaction.interval
        self.startsAt = recurringTransaction.startsAt
        self.nextOccurrenceAt = recurringTransaction.nextOccurrenceAt
        self.endsAt = recurringTransaction.endsAt
        self.isActive = recurringTransaction.isActive
        self.autopost = recurringTransaction.autopost
        self.lastGeneratedAt = recurringTransaction.lastGeneratedAt
        self.createdAt = recurringTransaction.createdAt
        self.updatedAt = recurringTransaction.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case rawTextTemplate = "raw_text_template"
        case amount
        case currencyCode = "currency_code"
        case transactionKind = "transaction_kind"
        case category
        case merchant
        case note
        case frequency
        case interval
        case startsAt = "starts_at"
        case nextOccurrenceAt = "next_occurrence_at"
        case endsAt = "ends_at"
        case isActive = "is_active"
        case autopost
        case lastGeneratedAt = "last_generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
