import SwiftUI

struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            illustration

            Spacer().frame(height: 52)

            headline
                .padding(.horizontal, 28)

            Spacer()

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var illustration: some View {
        Image("mascot-welcome")
            .resizable()
            .scaledToFit()
            .frame(width: 390, height: 390)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Notyfi")
                .font(.notyfi(.largeTitle, weight: .bold))
                .foregroundStyle(.primary)

            Text("The most frictionless way to track your spending.\nJust write it down.")
                .font(.notyfi(.body))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            OnboardingPrimaryButton(title: "Get Started", action: onGetStarted)

            Spacer().frame(height: 28)

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSignIn()
                } label: {
                    Text("Sign in")
                }
                .foregroundStyle(NotyfiTheme.brandPrimary)
            }
            .font(.notyfi(.subheadline))
        }
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {}, onSignIn: {})
}
