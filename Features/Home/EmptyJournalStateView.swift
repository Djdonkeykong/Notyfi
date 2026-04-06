import SwiftUI

struct EmptyJournalStateView: View {
    let selectedDate: Date

    private let examples = [
        "Coffee 49 kr".notyfiLocalized,
        "Groceries 423 at Rema".notyfiLocalized,
        "Train ticket 299".notyfiLocalized
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start with a note".notyfiLocalized)
                    .font(.notyfi(.title3, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))

                Text(
                    String(
                        format: "Nothing logged format".notyfiLocalized,
                        selectedDate.notyfiSectionTitle().lowercased(
                            with: .autoupdatingCurrent
                        )
                    )
                )
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(examples, id: \.self) { example in
                    Text(example)
                        .font(.notyfi(.footnote, weight: .medium))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassCapsule(material: .thinMaterial)
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
        .background(NotyfiBackgroundView())
}
