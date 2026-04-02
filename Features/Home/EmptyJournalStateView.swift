import SwiftUI

struct EmptyJournalStateView: View {
    let selectedDate: Date

    private let examples = [
        "Coffee 49 kr",
        "Groceries 423 at Rema",
        "Train ticket 299"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start with a note")
                    .font(.notely(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text("Nothing is logged for \(selectedDate.notelySectionTitle().lowercased()) yet. Type naturally and Notely will organize it quietly in the background.")
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

