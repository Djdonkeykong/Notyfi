import Auth
import Combine
import Foundation
import OSLog
import Supabase

@MainActor
final class CloudSyncManager: ObservableObject {
    @Published private(set) var isReady = true

    private let store: ExpenseJournalStore
    private let languageManager: LanguageManager
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.djdonkeykong.notely", category: "cloud-sync")
    private var cancellables = Set<AnyCancellable>()
    private var activeUserID: UUID?
    private var hasCompletedInitialSync = false
    private var isApplyingRemoteState = false
    private var pendingUploadTask: Task<Void, Never>?

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
            try await bootstrap(for: session.user)
            activeUserID = session.user.id
            hasCompletedInitialSync = true
        } catch {
            logger.error("Initial cloud sync failed: \(error.localizedDescription, privacy: .public)")
        }

        self.isReady = true
    }

    private func observeLocalChanges() {
        Publishers.CombineLatest3(store.$entries, store.$budgetPlan, store.$trackedCategories)
            .sink { [weak self] _, _, _ in
                self?.scheduleUpload()
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

        if shouldBootstrapLocalOnboarding, !remoteState.hasServerData {
            try await pushSnapshot(
                makeLocalSnapshot(),
                user: user
            )
            PendingOnboardingBootstrap.clear(defaults: defaults)

            let refreshedRemoteState = try await SupabaseFinanceService.fetchFinanceState(userID: user.id)
            apply(remoteState: refreshedRemoteState)
            return
        }

        if remoteState.hasServerData {
            PendingOnboardingBootstrap.clear(defaults: defaults)
            apply(remoteState: remoteState)
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
            defaults.set(languageCode, forKey: LanguageManager.storageKey)
            languageManager.applyStoredPreference()
        }

        let budgetPlan = remoteState.budgetPlan
        let trackedCategories = remoteState.trackedCategories
        let entries = remoteState.entries

        store.replaceAll(
            entries: entries,
            budgetPlan: budgetPlan,
            trackedCategories: trackedCategories
        )

        if let currencyCode = remoteState.user.currencyCode,
           let preference = NotyfiCurrency.preference(for: currencyCode) {
            defaults.set(preference.rawValue, forKey: NotyfiCurrency.storageKey)
        }

        if remoteState.user.onboardingCompletedAt != nil || remoteState.hasServerData {
            defaults.set(true, forKey: PendingOnboardingBootstrap.onboardingCompletedKey)
        }

        isApplyingRemoteState = false
    }

    private func makeLocalSnapshot() -> LocalFinanceSnapshot {
        LocalFinanceSnapshot(
            entries: store.entries,
            budgetPlan: store.budgetPlan,
            trackedCategories: store.trackedCategories,
            currencyCode: NotyfiCurrency.currentCode(defaults: defaults),
            languageCode: defaults.string(forKey: LanguageManager.storageKey) ?? NotyfiLanguage.system.rawValue,
            onboardingCompleted: defaults.bool(forKey: PendingOnboardingBootstrap.onboardingCompletedKey)
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
    let currencyCode: String
    let languageCode: String
    let onboardingCompleted: Bool
}

private struct RemoteFinanceState {
    let user: UserProfileRow
    let activePlan: BudgetPlanRow?
    let categoryTargets: [BudgetCategoryTargetRow]
    let entries: [ExpenseEntry]

    var hasServerData: Bool {
        user.onboardingCompletedAt != nil
            || user.monthlyBudget != nil
            || user.currencyCode != nil
            || user.languageCode != nil
            || activePlan != nil
            || !categoryTargets.isEmpty
            || !entries.isEmpty
    }

    var budgetPlan: BudgetPlan {
        var categoryTargetValues = categoryTargets.compactMap { row -> BudgetCategoryTarget? in
            guard let category = ExpenseCategory(rawValue: row.category) else {
                return nil
            }

            return BudgetCategoryTarget(
                category: category,
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
        Set(categoryTargets.compactMap { ExpenseCategory(rawValue: $0.category) })
    }

    static func empty(userID: UUID) -> RemoteFinanceState {
        RemoteFinanceState(
            user: UserProfileRow(id: userID, email: nil, displayName: nil, currencyCode: nil, languageCode: nil, monthlyBudget: nil, onboardingCompletedAt: nil),
            activePlan: nil,
            categoryTargets: [],
            entries: []
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

        async let entryRows: [ExpenseEntryRow] = SupabaseService.client
            .from("expense_entries")
            .select()
            .eq("user_id", value: userID.uuidString.lowercased())
            .execute()
            .value

        let fetchedUserRows = try await userRows
        let fetchedActivePlanRows = try await activePlanRows
        let fetchedEntryRows = try await entryRows

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
            entries: entries.sorted { lhs, rhs in
                if Calendar.current.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.date > rhs.date
            }
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

        try await replaceExpenseEntries(
            snapshot.entries,
            userID: userID
        )
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
    }

    var asExpenseEntry: ExpenseEntry {
        ExpenseEntry(
            id: id,
            rawText: rawText ?? title ?? "",
            title: title ?? rawText ?? "Untitled entry".notyfiLocalized,
            amount: amount,
            currencyCode: currencyCode,
            transactionKind: TransactionKind(rawValue: entryType) ?? .expense,
            category: ExpenseCategory(rawValue: category ?? "") ?? .uncategorized,
            merchant: merchant,
            date: occurredAt,
            note: note ?? "",
            confidence: ParsingConfidence(rawValue: confidence) ?? .review,
            isAmountEstimated: isAmountEstimated,
            createdAt: createdAt
        )
    }
}

private struct ExpenseEntryIdentifierRow: Decodable {
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
