import SwiftUI

struct OnboardingInputMethodsView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTag(text: "Just a heads up")
                    .padding(.bottom, 14)

                Text("You don't have to type everything")
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Three other quick ways to log a spend without stopping what you're doing.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                VStack(spacing: 12) {
                    InputMethodCard(
                        symbol: "camera.viewfinder",
                        color: Color(red: 0.38, green: 0.28, blue: 0.96),
                        title: "Snap a receipt",
                        description: "Point your camera at any receipt. Notyfi reads the total and logs it for you."
                    )
                    InputMethodCard(
                        symbol: "mic.fill",
                        color: Color(red: 0.95, green: 0.32, blue: 0.28),
                        title: "Speak it out",
                        description: "Say what you spent out loud. Notyfi transcribes and parses it instantly."
                    )
                    InputMethodCard(
                        symbol: "sparkles",
                        color: Color(red: 0.12, green: 0.60, blue: 0.42),
                        title: "Smart text",
                        description: "Abbreviations, shorthand, even typos — the AI figures out what you mean."
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct InputMethodCard: View {
    let symbol: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        OnboardingInputMethodsView()
    }
}
