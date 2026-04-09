import SwiftUI

struct OnboardingCurrencyView: View {
    let step: Int
    let totalSteps: Int
    let onNext: (NotyfiCurrencyPreference) -> Void
    let onBack: () -> Void

    @State private var selected: NotyfiCurrencyPreference = {
        let deviceCode = NotyfiCurrency.deviceCode.lowercased()
        return NotyfiCurrencyPreference.allCases.first { $0.rawValue == deviceCode } ?? .usd
    }()

    private var currencies: [NotyfiCurrencyPreference] {
        NotyfiCurrencyPreference.allCases.filter { $0 != .auto }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingNavBar(currentStep: step, totalSteps: totalSteps, onBack: onBack)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    illustration
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

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

            OnboardingPrimaryButton(title: "Continue") {
                onNext(selected)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var illustration: some View {
        OnboardingIllustration(symbol: "banknote.fill", size: 68)
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
                    }
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
    OnboardingCurrencyView(step: 2, totalSteps: 5, onNext: { _ in }, onBack: {})
}
