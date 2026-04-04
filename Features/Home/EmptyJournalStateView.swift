import SwiftUI

struct EmptyJournalStateView: View {
    let selectedDate: Date

    private let examples = [
        "Coffee 49 kr".notelyLocalized,
        "Groceries 423 at Rema".notelyLocalized,
        "Train ticket 299".notelyLocalized
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start with a note".notelyLocalized)
                    .font(.notely(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text(
                    String(
                        format: "Nothing logged format".notelyLocalized,
                        selectedDate.notelySectionTitle().lowercased(
                            with: .autoupdatingCurrent
                        )
                    )
                )
                    .font(.notely(.body))
                    .foregroundStyle(NotelyTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(examples, id: \.self) { example in
                    Text(example)
                        .font(.notely(.footnote, weight: .medium))
                        .foregroundStyle(NotelyTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(NotelyTheme.elevatedSurface)
                                .overlay {
                                    Capsule()
                                        .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                                }
                        }
                }
            }

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .padding(.vertical, 10)
    }
}

#Preview {
    EmptyJournalStateView(selectedDate: Date())
        .padding()
        .background(NotelyTheme.background)
}
