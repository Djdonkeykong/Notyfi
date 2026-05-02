import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var viewModel: EntryDetailViewModel
    @State private var shouldPersistOnDisappear = true
    @State private var recurringDraft: RecurringTransactionDraft?
    @State private var isNewCategoryPresented = false
    @State private var isDeleteConfirmationPresented = false
    private let isNewEntryDraft: Bool
    private let store: ExpenseJournalStore
    private let entryID: UUID

    @AppStorage(NotyfiCurrency.storageKey) private var currencyRaw = NotyfiCurrencyPreference.auto.rawValue
    private var currencyCode: String {
        NotyfiCurrencyPreference(rawValue: currencyRaw)?.currencyCode ?? NotyfiCurrency.deviceCode
    }

    init(entry: ExpenseEntry, store: ExpenseJournalStore, isNewEntryDraft: Bool = false) {
        _viewModel = StateObject(wrappedValue: EntryDetailViewModel(entry: entry, store: store))
        self.isNewEntryDraft = isNewEntryDraft
        self.store = store
        self.entryID = entry.id
    }

    var body: some View {
        let _ = languageManager.refreshID

        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    summaryCard
                    if !isNewEntryDraft {
                        SectionHeader(title: "Original Note")
                        detailCard {
                            VStack(alignment: .leading, spacing: 14) {
                                TextField("\("Coffee".notyfiLocalized) \(NotyfiCurrency.coffeePlaceholderAmount(for: currencyCode).formattedCurrency(code: currencyCode))", text: $viewModel.rawText, axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(.notyfi(.title3, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.86))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                        }
                    }

                    SectionHeader(title: "Entry Details")
                    detailCard {
                        VStack(spacing: 0) {
                            DetailTextField(
                                title: "Title",
                                text: $viewModel.title,
                                placeholder: "Coffee".notyfiLocalized
                            )

                            Divider()

                            DetailTextField(
                                title: "Amount",
                                text: $viewModel.amountText,
                                placeholder: "0"
                            )

                            Divider()

                            DetailPickerRow(title: "Type") {
                                Picker("Type".notyfiLocalized, selection: $viewModel.transactionKind) {
                                    ForEach(TransactionKind.allCases) { kind in
                                        Text(kind.title).tag(kind)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .tint(.primary.opacity(0.84))
                            }

                            Divider()

                            DetailPickerRow(title: "Category") {
                                Menu {
                                    Picker("Category".notyfiLocalized, selection: $viewModel.category) {
                                        ForEach(ExpenseCategory.allCases) { category in
                                            Label(category.title, systemImage: category.symbol).tag(category)
                                        }
                                    }
                                    if !store.customCategories.isEmpty {
                                        Picker("Custom".notyfiLocalized, selection: $viewModel.category) {
                                            ForEach(store.customCategories.map(\.asExpenseCategory)) { category in
                                                Label(category.title, systemImage: category.symbol).tag(category)
                                            }
                                        }
                                    }
                                    Button {
                                        isNewCategoryPresented = true
                                    } label: {
                                        Label("New Category".notyfiLocalized, systemImage: "plus.circle.fill")
                                    }
                                } label: {
                                    Text(viewModel.category.title)
                                        .font(.notyfi(.body))
                                        .foregroundStyle(.primary.opacity(0.84))
                                }
                            }
                            .sheet(isPresented: $isNewCategoryPresented) {
                                CustomCategoryEditorView { newDef in
                                    store.addCustomCategory(newDef)
                                    viewModel.category = newDef.asExpenseCategory
                                }
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                            }

                            Divider()

                            DetailDateRow(date: $viewModel.date)

                            Divider()

                            DetailTextField(
                                title: "Merchant",
                                text: $viewModel.merchant,
                                placeholder: "Optional"
                            )
                        }
                    }

                    SectionHeader(title: "Notes & Review")
                    detailCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Toggle("Needs review".notyfiLocalized, isOn: $viewModel.needsReview)
                                .tint(NotyfiTheme.reviewTint)
                                .font(.notyfi(.body, weight: .medium))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note".notyfiLocalized)
                                    .font(.notyfi(.footnote, weight: .medium))
                                    .foregroundStyle(NotyfiTheme.secondaryText)

                                TextField("Optional context".notyfiLocalized, text: $viewModel.note, axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(.notyfi(.body))
                                    .foregroundStyle(.primary.opacity(0.84))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)

                            Divider()

                            HStack(spacing: 10) {
                                Circle()
                                    .fill(viewModel.confidenceColor.opacity(0.16))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Image(systemName: viewModel.confidenceIcon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(viewModel.confidenceColor)
                                    }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Confidence".notyfiLocalized)
                                        .font(.notyfi(.footnote, weight: .medium))
                                        .foregroundStyle(NotyfiTheme.secondaryText)

                                    Text(viewModel.confidenceTitle)
                                        .font(.notyfi(.body, weight: .semibold))
                                        .foregroundStyle(viewModel.confidenceColor)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }

                    if !isNewEntryDraft {
                        SectionHeader(title: "Danger Zone")
                        detailCard {
                            Button {
                                isDeleteConfirmationPresented = true
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.red.opacity(0.75))
                                        .frame(width: 18)
                                    Text("Delete Entry".notyfiLocalized)
                                        .font(.notyfi(.body))
                                        .foregroundStyle(.red.opacity(0.78))
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionHeader(title: "Automation")
                    detailCard {
                        Button(action: presentRecurringEditor) {
                            HStack(spacing: 14) {
                                Image(systemName: "repeat.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(NotyfiTheme.brandBlue.opacity(0.88))
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recurringActionTitle)
                                        .font(.notyfi(.body))
                                        .foregroundStyle(.primary.opacity(0.82))

                                    Text(recurringActionSubtitle)
                                        .font(.notyfi(.caption))
                                        .foregroundStyle(NotyfiTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NotyfiTheme.tertiaryText)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 32)
                .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $recurringDraft) { draft in
            RecurringTransactionEditorView(
                draft: draft,
                store: store,
                sourceEntryID: entryID
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NotyfiTheme.background.opacity(0.98))
            .presentationCornerRadius(34)
        }
        .confirmationDialog(
            "Delete entry?".notyfiLocalized,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Entry".notyfiLocalized, role: .destructive) {
                shouldPersistOnDisappear = false
                store.removeEntry(id: entryID)
                dismiss()
            }
            Button("Cancel".notyfiLocalized, role: .cancel) {}
        } message: {
            Text("This entry will be removed from your log.".notyfiLocalized)
        }
        .onDisappear {
            if shouldPersistOnDisappear {
                viewModel.save()
            } else if isNewEntryDraft {
                store.removeEntry(id: entryID)
            }
        }
    }

    private var currentRecurringTransactionID: UUID? {
        store.entries.first(where: { $0.id == entryID })?.recurringTransactionID
            ?? viewModel.recurringTransactionID
    }

    private var recurringActionTitle: String {
        store.recurringTransaction(id: currentRecurringTransactionID) == nil
            ? "Make recurring".notyfiLocalized
            : "Edit recurring".notyfiLocalized
    }

    private var recurringActionSubtitle: String {
        store.recurringTransaction(id: currentRecurringTransactionID) == nil
            ? "Turn this entry into a repeating rule.".notyfiLocalized
            : "Update the repeating rule behind this entry.".notyfiLocalized
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Entry Details".notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Text(viewModel.displayTitle)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                CircleActionButton(systemImage: "checkmark") {
                    shouldPersistOnDisappear = true
                    viewModel.save()
                    dismiss()
                }

                CircleActionButton(systemImage: "xmark") {
                    shouldPersistOnDisappear = false
                    dismiss()
                }
            }
        }
        .padding(.top, 8)
    }

    private var summaryCard: some View {
        detailCard {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(viewModel.formattedAmount)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(viewModel.amountColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(viewModel.summaryCaption)
                        .font(.notyfi(.footnote))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()
                }

                HStack(spacing: 12) {
                    SummaryMetricChip(
                        value: viewModel.category.title,
                        label: "Category",
                        tint: viewModel.category.tint,
                        systemImage: viewModel.category.symbol
                    )

                    SummaryMetricChip(
                        value: viewModel.merchantDisplay,
                        label: "Merchant",
                        tint: Color(red: 0.27, green: 0.58, blue: 0.92),
                        systemImage: "building.2.fill"
                    )

                    SummaryMetricChip(
                        value: viewModel.date.notyfiTimeLabel(),
                        label: "Time",
                        tint: Color(red: 0.71, green: 0.43, blue: 0.84),
                        systemImage: "clock.fill"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 18, x: 0, y: 8)
            }
    }

    private func presentRecurringEditor() {
        viewModel.save()
        recurringDraft = viewModel.recurringDraft(using: store)
    }
}

private struct CircleActionButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.mediumImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(NotyfiTheme.elevatedSurface)
                        .overlay {
                            Circle()
                                .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryMetricChip: View {
    let value: String
    let label: String
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.notyfi(.footnote, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)

                Text(label.notyfiLocalized)
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.notyfiLocalized)
                .font(.notyfi(.footnote, weight: .medium))
                .foregroundStyle(NotyfiTheme.secondaryText)

            TextField(placeholder.notyfiLocalized, text: $text)
                .font(.notyfi(.body))
                .foregroundStyle(.primary.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct DetailPickerRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                content()
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct DetailDateRow: View {
    @Binding var date: Date

    var body: some View {
        DatePicker(
            "Date".notyfiLocalized,
            selection: $date,
            displayedComponents: [.date, .hourAndMinute]
        )
        .font(.notyfi(.body))
        .tint(NotyfiTheme.reviewTint)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private extension EntryDetailViewModel {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled entry".notyfiLocalized : trimmed
    }

    var formattedAmount: String {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let formattedAmount = amount.formattedCurrency(code: currencyCode)
        return transactionKind == .income ? "+\(formattedAmount)" : "-\(formattedAmount)"
    }

    var amountColor: Color {
        transactionKind == .income
            ? NotyfiTheme.incomeColor
            : NotyfiTheme.expenseColor
    }

    var merchantDisplay: String {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Personal".notyfiLocalized : trimmed
    }

    var confidenceTitle: String {
        if isAmountEstimated, needsReview {
            return "Estimated price".notyfiLocalized
        }

        return needsReview ? "Needs review".notyfiLocalized : "Ready".notyfiLocalized
    }

    var confidenceColor: Color {
        needsReview ? NotyfiTheme.reviewTint : NotyfiTheme.incomeColor
    }

    var confidenceIcon: String {
        if isAmountEstimated, needsReview {
            return "sparkles"
        }

        return needsReview ? "wand.and.stars" : "checkmark.seal.fill"
    }

    var summaryCaption: String {
        if isAmountEstimated, needsReview {
            return "estimated total".notyfiLocalized
        }

        return amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "amount pending".notyfiLocalized
            : "captured total".notyfiLocalized
    }
}

#Preview {
    EntryDetailView(
        entry: ExpenseEntry(
            rawText: "Dinner at McDonald's 145",
            title: "Dinner",
            amount: 145,
            category: .food,
            merchant: "McDonald's",
            date: Date(),
            note: "Late dinner after work.",
            confidence: .review
        ),
        store: ExpenseJournalStore(previewMode: true)
    )
}
