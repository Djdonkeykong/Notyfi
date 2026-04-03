import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryDetailViewModel

    init(entry: ExpenseEntry, store: ExpenseJournalStore) {
        _viewModel = StateObject(wrappedValue: EntryDetailViewModel(entry: entry, store: store))
    }

    var body: some View {
        ZStack {
            NotelyTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    summaryCard
                    SectionHeader(title: "Original Note")
                    detailCard {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Coffee 49 kr", text: $viewModel.rawText, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.notely(.title3, weight: .medium))
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

                            DetailPickerRow(title: "Category") {
                                Picker("Category", selection: $viewModel.category) {
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
                            Toggle("Needs review", isOn: $viewModel.needsReview)
                                .tint(NotelyTheme.reviewTint)
                                .font(.notely(.body, weight: .medium))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note")
                                    .font(.notely(.footnote, weight: .medium))
                                    .foregroundStyle(NotelyTheme.secondaryText)

                                TextField("Optional context", text: $viewModel.note, axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(.notely(.body))
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
                                    Text("Confidence")
                                        .font(.notely(.footnote, weight: .medium))
                                        .foregroundStyle(NotelyTheme.secondaryText)

                                    Text(viewModel.confidenceTitle)
                                        .font(.notely(.body, weight: .semibold))
                                        .foregroundStyle(viewModel.confidenceColor)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                            if let parseFailureMessage = viewModel.parseFailureMessage,
                               !parseFailureMessage.isEmpty {
                                Divider()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Parser Debug")
                                        .font(.notely(.footnote, weight: .medium))
                                        .foregroundStyle(NotelyTheme.secondaryText)

                                    Text(parseFailureMessage)
                                        .font(.notely(.footnote))
                                        .foregroundStyle(.red.opacity(0.78))
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .safeAreaPadding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .onDisappear {
            viewModel.save()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Entry Details")
                    .font(.notely(.footnote, weight: .semibold))
                    .foregroundStyle(NotelyTheme.secondaryText)

                Text(viewModel.displayTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                CircleActionButton(systemImage: "checkmark") {
                    viewModel.save()
                    dismiss()
                }

                CircleActionButton(systemImage: "xmark") {
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
                        .foregroundStyle(.primary.opacity(0.94))
                        .monospacedDigit()

                    Text(viewModel.summaryCaption)
                        .font(.notely(.body))
                        .foregroundStyle(NotelyTheme.secondaryText)

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
                    .fill(NotelyTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 18, x: 0, y: 8)
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
                .foregroundStyle(NotelyTheme.secondaryText)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(NotelyTheme.elevatedSurface)
                        .overlay {
                            Circle()
                                .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
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
                .font(.notely(.body, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)

                Text(label)
                    .font(.notely(.caption))
                    .foregroundStyle(NotelyTheme.secondaryText)
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
            Text(title)
                .font(.notely(.footnote, weight: .medium))
                .foregroundStyle(NotelyTheme.secondaryText)

            TextField(placeholder, text: $text)
                .font(.notely(.body))
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
                Text(title)
                    .font(.notely(.footnote, weight: .medium))
                    .foregroundStyle(NotelyTheme.secondaryText)

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
            "Date",
            selection: $date,
            displayedComponents: [.date, .hourAndMinute]
        )
        .font(.notely(.body))
        .tint(NotelyTheme.reviewTint)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

private extension EntryDetailViewModel {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled entry" : trimmed
    }

    var formattedAmount: String {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return amount.formattedCurrency(code: currencyCode)
    }

    var merchantDisplay: String {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Personal" : trimmed
    }

    var confidenceTitle: String {
        needsReview ? "Needs review" : "Ready"
    }

    var confidenceColor: Color {
        needsReview ? NotelyTheme.reviewTint : Color(red: 0.28, green: 0.71, blue: 0.45)
    }

    var confidenceIcon: String {
        needsReview ? "wand.and.stars" : "checkmark.seal.fill"
    }

    var summaryCaption: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "amount pending" : "captured total"
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
