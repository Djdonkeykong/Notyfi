import SwiftUI
import Lottie

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
        let priority: [NotyfiCurrencyPreference] = [.usd, .eur]
        let rest = NotyfiCurrencyPreference.allCases
            .filter { $0 != .auto && !priority.contains($0) }
        return priority + rest
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                LottieView(animation: .named("mascot-money"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .padding(.vertical, 24)

                Text("Pick your currency")
                    .font(.notyfi(.title2, weight: .bold))
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
        .background(NotyfiTheme.brandLight)
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
                        let symbol = currencySymbol(for: currency.currencyCode)
                        Text(symbol)
                            .font(symbolFont(for: symbol))
                            .foregroundStyle(NotyfiTheme.brandPrimary)
                            .frame(width: 36, alignment: .center)
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

    private func symbolFont(for symbol: String) -> Font {
        switch symbol.count {
        case 1:  return .notyfi(.title3, weight: .semibold)   // $, €, £, ¥
        case 2:  return .notyfi(.body, weight: .semibold)     // A$, S$, NZ$-style
        default: return .system(size: 11, weight: .bold, design: .rounded) // NOK, SEK, CHF …
        }
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
