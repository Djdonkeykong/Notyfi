import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryDetailViewModel

    init(entry: ExpenseEntry, store: ExpenseJournalStore) {
        _viewModel = StateObject(wrappedValue: EntryDetailViewModel(entry: entry, store: store))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SoftSurface(cornerRadius: 30, padding: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Original note")
                            .font(.notely(.footnote, weight: .medium))
                            .foregroundStyle(NotelyTheme.secondaryText)

                        TextField("Coffee 49 kr", text: $viewModel.rawText, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.notely(.title3, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.84))
                    }
                }

                SoftSurface(cornerRadius: 30, padding: 20) {
                    VStack(spacing: 16) {
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

                        Picker("Category", selection: $viewModel.category) {
                            ForEach(ExpenseCategory.allCases) { category in
                                Text(category.title).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary.opacity(0.84))

                        Divider()

                        DatePicker(
                            "Date",
                            selection: $viewModel.date,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .tint(NotelyTheme.reviewTint)

                        Divider()

                        DetailTextField(
                            title: "Merchant",
                            text: $viewModel.merchant,
                            placeholder: "Optional"
                        )
                    }
                }

                SoftSurface(cornerRadius: 30, padding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Needs review", isOn: $viewModel.needsReview)
                            .tint(NotelyTheme.reviewTint)
                            .font(.notely(.body, weight: .medium))

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.notely(.footnote, weight: .medium))
                                .foregroundStyle(NotelyTheme.secondaryText)

                            TextField("Optional context", text: $viewModel.note, axis: .vertical)
                                .lineLimit(2...5)
                                .font(.notely(.body))
                        }

                        Text("Future AI parsing can re-check the raw note and quietly suggest field updates here.")
                            .font(.notely(.caption))
                            .foregroundStyle(NotelyTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(NotelyTheme.background.ignoresSafeArea())
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    viewModel.save()
                    dismiss()
                }
                .font(.notely(.body, weight: .semibold))
            }
        }
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
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(
            entry: ExpenseEntry(
                rawText: "Coffee 49 kr",
                title: "Coffee",
                amount: 49,
                category: .food,
                merchant: "Talormade",
                date: Date(),
                note: "Quick stop before the train.",
                confidence: .review
            ),
            store: ExpenseJournalStore(previewMode: true)
        )
    }
}
