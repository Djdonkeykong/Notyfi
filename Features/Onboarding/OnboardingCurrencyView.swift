import SwiftUI

struct OnboardingCurrencyView: View {
    @Binding var currencyRawValue: String
    @State private var selected: NotyfiCurrencyPreference

    init(currencyRawValue: Binding<String>) {
        _currencyRawValue = currencyRawValue
        let stored = NotyfiCurrencyPreference(rawValue: currencyRawValue.wrappedValue)
        if let stored, stored != .auto {
            _selected = State(initialValue: stored)
        } else {
            let deviceCode = NotyfiCurrency.deviceCode.lowercased()
            let device = NotyfiCurrencyPreference.allCases.first { $0.rawValue == deviceCode } ?? .usd
            _selected = State(initialValue: device)
        }
    }

    private var currencies: [NotyfiCurrencyPreference] {
        NotyfiCurrencyPreference.allCases.filter { $0 != .auto }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIllustration(symbol: "banknote.fill", size: 68)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                Text("Pick your currency")
                    .font(.notyfi(.title, weight: .bold))
                    .padding(.bottom, 10)

                Text("Used to format your entries and budget. You can change this later.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                currencyList
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 120, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selected) { _, newValue in
            currencyRawValue = newValue.rawValue
        }
    }

    private var currencyList: some View {
        VStack(spacing: 10) {
            ForEach(currencies) { currency in
                OnboardingSelectionCard(isSelected: selected == currency) {
                    selected = currency
                } content: {
                    HStack(spacing: 14) {
                        Text(currencySymbol(for: currency.currencyCode))
                            .font(.notyfi(.title3, weight: .semibold))
                            .foregroundStyle(NotyfiTheme.brandPrimary)
                            .frame(width: 32)
                        Text(currency.title)
                            .font(.notyfi(.subheadline))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .frame(height: 28)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func currencySymbol(for code: String) -> String {
        let locale = Locale(identifier: "en_US")
        return locale.localizedString(forCurrencyCode: code)
            .flatMap { _ in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = code
                formatter.locale = locale
                return formatter.currencySymbol
            } ?? code
    }
}

#Preview {
    NavigationStack {
        OnboardingCurrencyView(currencyRawValue: .constant("usd"))
    }
}
