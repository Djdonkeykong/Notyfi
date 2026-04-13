import SwiftUI

struct RecurringTransactionsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ExpenseJournalStore

    @State private var editorDraft: RecurringTransactionDraft?

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    if store.recurringTransactions.isEmpty {
                        emptyState
                    } else {
                        recurringList
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .sheet(item: $editorDraft) { draft in
            RecurringTransactionEditorView(
                draft: draft,
                store: store
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NotyfiTheme.background.opacity(0.98))
            .presentationCornerRadius(34)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recurring".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text("Manage bills, paychecks, and anything that repeats.".notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: presentNewRecurringEditor) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .frame(width: 38, height: 38)
                        .background {
                            Circle()
                                .fill(NotyfiTheme.elevatedSurface)
                        }
                }
                .buttonStyle(.plain)

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
        }
        .padding(.top, 22)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(NotyfiTheme.brandBlue.opacity(0.86))

            VStack(spacing: 6) {
                Text("No recurring items yet".notyfiLocalized)
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text("Create one from quick add, from an entry, or tap the plus button here.".notyfiLocalized)
                    .font(.notyfi(.footnote))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
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

    private var recurringList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Active rules")

            VStack(spacing: 12) {
                ForEach(store.recurringTransactions) { recurringTransaction in
                    RecurringTransactionRow(
                        recurringTransaction: recurringTransaction,
                        onTap: {
                            editorDraft = RecurringTransactionDraft(transaction: recurringTransaction)
                        },
                        onToggleActive: { isActive in
                            var updated = recurringTransaction
                            updated.isActive = isActive
                            updated.updatedAt = Date()
                            store.saveRecurringTransaction(updated)
                        }
                    )
                }
            }
        }
    }

    private func presentNewRecurringEditor() {
        editorDraft = RecurringTransactionDraft(
            title: "Recurring expense".notyfiLocalized,
            rawTextTemplate: "Recurring expense".notyfiLocalized,
            amountText: "",
            currencyCode: NotyfiCurrency.currentCode(),
            transactionKind: .expense,
            category: .bills
        )
    }
}

private struct RecurringTransactionRow: View {
    let recurringTransaction: RecurringTransaction
    let onTap: () -> Void
    let onToggleActive: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(rowTint.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: recurringTransaction.transactionKind == .income ? "arrow.down.left.circle.fill" : "repeat.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(rowTint)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recurringTransaction.title)
                            .font(.notyfi(.body, weight: .semibold))
                            .foregroundStyle(NotyfiTheme.primaryText)

                        Text(recurringTransaction.scheduleSummary)
                            .font(.notyfi(.footnote))
                            .foregroundStyle(NotyfiTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 8) {
                Text(recurringTransaction.amount.formattedCurrency(code: recurringTransaction.currencyCode))
                    .font(.notyfi(.footnote, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Toggle(
                    "",
                    isOn: Binding(
                        get: { recurringTransaction.isActive },
                        set: onToggleActive
                    )
                )
                .labelsHidden()
                .tint(NotyfiTheme.brandBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NotyfiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private var rowTint: Color {
        recurringTransaction.transactionKind == .income
            ? NotyfiTheme.incomeColor
            : Color(red: 0.74, green: 0.55, blue: 0.25)
    }
}

#Preview {
    RecurringTransactionsSheetView(store: ExpenseJournalStore(previewMode: true))
}
