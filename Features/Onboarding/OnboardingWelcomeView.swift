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
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 220, height: 220)
                .shadow(color: NotyfiTheme.brandPrimary.opacity(0.10), radius: 40, x: 0, y: 12)

            Image(systemName: "note.text")
                .font(.system(size: 88, weight: .thin))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NotyfiTheme.brandPrimary)
        }
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
        VStack(spacing: 16) {
            OnboardingPrimaryButton(title: "Get Started", action: onGetStarted)

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Button("Sign in", action: onSignIn)
                    .foregroundStyle(NotyfiTheme.brandPrimary)
            }
            .font(.notyfi(.subheadline))
        }
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {}, onSignIn: {})
}
