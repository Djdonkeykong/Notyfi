import SwiftUI

struct OnboardingHowItWorksView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingIllustration(symbol: "text.cursor", size: 72)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                OnboardingTag(text: "Quick tip")
                    .padding(.bottom, 14)

                Text("Just write what you spent")
                    .font(.notyfi(.title, weight: .bold))
                    .padding(.bottom, 10)

                Text("Type anything naturally. Notyfi reads it and fills in the details.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                examples
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var examples: some View {
        VStack(spacing: 10) {
            ExampleRow(input: "Coffee at the station 4.50",
                       output: "Coffee  \u{b7}  Food  \u{b7}  4.50")
            ExampleRow(input: "Spotify monthly 9.99",
                       output: "Spotify  \u{b7}  Bills  \u{b7}  9.99")
            ExampleRow(input: "Rent 1200",
                       output: "Rent  \u{b7}  Housing  \u{b7}  1,200")
        }
    }
}

private struct ExampleRow: View {
    let input: String
    let output: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Text(input)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 8) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary.opacity(0.5))
                    .padding(.leading, 2)
                Text(output)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        OnboardingHowItWorksView()
    }
}
