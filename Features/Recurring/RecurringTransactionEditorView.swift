import SwiftUI

struct RecurringTransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RecurringTransactionDraft
    @ObservedObject private var store: ExpenseJournalStore
    private let sourceEntryID: UUID?

    init(
        draft: RecurringTransactionDraft,
        store: ExpenseJournalStore,
        sourceEntryID: UUID? = nil
    ) {
        _draft = State(initialValue: draft)
        self.store = store
        self.sourceEntryID = sourceEntryID
    }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    detailSection
                    scheduleSection

                    if existingRecurringTransaction != nil {
                        destructiveSection
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: saveRecurringTransaction) {
                Text(saveButtonTitle)
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(draft.canSave ? NotyfiTheme.brandBlue : NotyfiTheme.brandBlue.opacity(0.38))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!draft.canSave)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background {
                LinearGradient(
                    colors: [NotyfiTheme.background.opacity(0), NotyfiTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private var existingRecurringTransaction: RecurringTransaction? {
        store.recurringTransaction(id: draft.id)
    }

    private var sourceEntry: ExpenseEntry? {
        guard let sourceEntryID else {
            return nil
        }

        return store.entries.first(where: { $0.id == sourceEntryID })
    }

    private var saveButtonTitle: String {
        existingRecurringTransaction == nil
            ? "Save recurring item".notyfiLocalized
            : "Update recurring item".notyfiLocalized
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recurring".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text("Create something that should land in your journal automatically.".notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(NotyfiTheme.elevatedSurface)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Details")

            recurringCard {
                VStack(spacing: 0) {
                    RecurringTextFieldRow(
                        title: "Title",
                        text: $draft.title,
                        placeholder: "Rent".notyfiLocalized
                    )

                    Divider()

                    RecurringTextFieldRow(
                        title: "Original note",
                        text: $draft.rawTextTemplate,
                        placeholder: "Rent 12000".notyfiLocalized
                    )

                    Divider()

                    RecurringTextFieldRow(
                        title: "Amount",
                        text: $draft.amountText,
                        placeholder: "0"
                    )

                    Divider()

                    RecurringMenuRow(title: "Type") {
                        Picker("Type".notyfiLocalized, selection: $draft.transactionKind) {
                            ForEach(TransactionKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Divider()

                    RecurringMenuRow(title: "Category") {
                        Picker("Category".notyfiLocalized, selection: $draft.category) {
                            ForEach(ExpenseCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Divider()

                    RecurringValueRow(
                        title: "Currency",
                        value: draft.currencyCode.uppercased()
                    )

                    Divider()

                    RecurringTextFieldRow(
                        title: "Merchant",
                        text: $draft.merchant,
                        placeholder: "Optional".notyfiLocalized
                    )

                    Divider()

                    RecurringTextFieldRow(
                        title: "Note",
                        text: $draft.note,
                        placeholder: "Optional context".notyfiLocalized
                    )
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Schedule")

            recurringCard {
                VStack(spacing: 0) {
                    RecurringMenuRow(title: "Frequency") {
                        Picker("Frequency".notyfiLocalized, selection: $draft.frequency) {
                            ForEach(RecurringFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Divider()

                    DatePicker(
                        "Starts".notyfiLocalized,
                        selection: $draft.startsAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.notyfi(.body))
                    .tint(NotyfiTheme.brandBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)

                    Divider()

                    Toggle("End date".notyfiLocalized, isOn: $draft.hasEndDate)
                        .tint(NotyfiTheme.brandBlue)
                        .font(.notyfi(.body, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)

                    if draft.hasEndDate {
                        Divider()

                        DatePicker(
                            "Ends".notyfiLocalized,
                            selection: $draft.endsAt,
                            in: draft.startsAt...,
                            displayedComponents: [.date]
                        )
                        .font(.notyfi(.body))
                        .tint(NotyfiTheme.brandBlue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }

                    Divider()

                    Toggle("Active".notyfiLocalized, isOn: $draft.isActive)
                        .tint(NotyfiTheme.brandBlue)
                        .font(.notyfi(.body, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    private var destructiveSection: some View {
        recurringCard {
            Button(role: .destructive, action: deleteRecurringTransaction) {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.78))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 18)

                    Text("Delete recurring item".notyfiLocalized)
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

    private func recurringCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 16, x: 0, y: 8)
            }
    }

    private func saveRecurringTransaction() {
        let recurringTransaction = draft.recurringTransaction(existing: existingRecurringTransaction)
        let shouldLinkSourceEntry = sourceEntry != nil

        store.saveRecurringTransaction(
            recurringTransaction,
            materializeDueEntries: !shouldLinkSourceEntry
        )

        if let sourceEntry {
            var updatedEntry = sourceEntry
            updatedEntry.recurringTransactionID = recurringTransaction.id
            updatedEntry.recurrenceInstanceKey = RecurringTransaction.recurrenceInstanceKey(
                recurringTransactionID: recurringTransaction.id,
                occurrenceDate: sourceEntry.date
            )
            store.updateEntry(updatedEntry)
        }

        if shouldLinkSourceEntry {
            _ = store.materializeDueRecurringEntries(upTo: Date())
        }

        dismiss()
    }

    private func deleteRecurringTransaction() {
        guard let recurringTransaction = existingRecurringTransaction else {
            return
        }

        store.removeRecurringTransaction(id: recurringTransaction.id)
        dismiss()
    }
}

private struct RecurringTextFieldRow: View {
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

private struct RecurringMenuRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                content()
                    .tint(.primary.opacity(0.84))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private struct RecurringValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Text(value)
                    .font(.notyfi(.body))
                    .foregroundStyle(.primary.opacity(0.84))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

#Preview {
    RecurringTransactionEditorView(
        draft: RecurringTransactionDraft(
            title: "Rent",
            rawTextTemplate: "Rent 12000",
            amountText: "12000",
            currencyCode: "NOK",
            transactionKind: .expense,
            category: .housing
        ),
        store: ExpenseJournalStore(previewMode: true)
    )
}
