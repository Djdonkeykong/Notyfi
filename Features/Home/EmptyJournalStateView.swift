import SwiftUI

struct EmptyJournalStateView: View {
    let selectedDate: Date

    @AppStorage(NotyfiCurrency.storageKey) private var currencyRaw = NotyfiCurrencyPreference.auto.rawValue

    private var currencyCode: String {
        NotyfiCurrencyPreference(rawValue: currencyRaw)?.currencyCode ?? NotyfiCurrency.deviceCode
    }

    private var examples: [String] {
        [
            "\("Coffee".notyfiLocalized) \(NotyfiCurrency.coffeePlaceholderAmount(for: currencyCode).formattedCurrency(code: currencyCode))",
            "Groceries 423 at Rema".notyfiLocalized,
            "Train ticket 299".notyfiLocalized
        ]
    }

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
                            with: NotyfiLocale.current()
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
                        .background {
                            Capsule()
                                .fill(NotyfiTheme.elevatedSurface)
                                .overlay {
                                    Capsule()
                                        .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
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
        .background(NotyfiTheme.background)
}
