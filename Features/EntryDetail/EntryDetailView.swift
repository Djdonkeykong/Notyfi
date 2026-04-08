import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryDetailViewModel
    @State private var shouldPersistOnDisappear = true
    private let isNewEntryDraft: Bool
    private let store: ExpenseJournalStore
    private let entryID: UUID

    init(entry: ExpenseEntry, store: ExpenseJournalStore, isNewEntryDraft: Bool = false) {
        _viewModel = StateObject(wrappedValue: EntryDetailViewModel(entry: entry, store: store))
        self.isNewEntryDraft = isNewEntryDraft
        self.store = store
        self.entryID = entry.id
    }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    summaryCard
                    SectionHeader(title: "Original Note")
                    detailCard {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Coffee 49 kr".notyfiLocalized, text: $viewModel.rawText, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.notyfi(.title3, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.86))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }

                    SectionHeader(title: "Entry Details")
                    detailCard {
                        VStack(spacing: 0) {
                            DetailTextField(
                                title: "Title",
                                text: $viewModel.title,
                                placeholder: "Coffee"
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
                                Picker("Category".notyfiLocalized, selection: $viewModel.category) {
                                    ForEach(ExpenseCategory.allCases) { category in
                                        Text(category.title).tag(category)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .tint(.primary.opacity(0.84))
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
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .onDisappear {
            if shouldPersistOnDisappear {
                viewModel.save()
            } else if isNewEntryDraft {
                store.removeEntry(id: entryID)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Entry Details".notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.secondaryText)

                Text(viewModel.displayTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
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
                    if isNewEntryDraft {
                        shouldPersistOnDisappear = false
                    }
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
                    Text("\u{1F525}")
                        .font(.system(size: 24))

                    Text(viewModel.formattedAmount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.amountColor)
                        .monospacedDigit()

                    Text(viewModel.summaryCaption)
                        .font(.notyfi(.body))
                        .foregroundStyle(NotyfiTheme.secondaryText)

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
                        value: viewModel.date.formatted(.dateTime.hour().minute()),
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
                .font(.notyfi(.body, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
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
            ? Color(red: 0.28, green: 0.71, blue: 0.45)
            : Color(red: 0.90, green: 0.36, blue: 0.34)
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
        needsReview ? NotyfiTheme.reviewTint : Color(red: 0.28, green: 0.71, blue: 0.45)
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
