import SwiftUI

struct OnboardingInputMethodsView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 0) {
                Text("Just a heads up".notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NotyfiTheme.brandLight)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NotyfiTheme.brandPrimary.opacity(0.25), lineWidth: 1))
                    .padding(.bottom, 20)

                HStack(alignment: .center, spacing: 10) {
                    Text("You don't have to type everything".notyfiLocalized)
                        .font(.notyfi(.title2, weight: .bold))
                        .multilineTextAlignment(.center)

                    Image("onboarding-camera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

                Text("There are two easy ways to log a spend without stopping what you're doing.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    Image("photo-card")
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Image("dictation-card")
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

#Preview {
    NavigationStack {
        OnboardingInputMethodsView()
    }
}
