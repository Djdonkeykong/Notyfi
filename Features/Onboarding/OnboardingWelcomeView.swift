import SwiftUI

struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showLanguagePicker = false

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
        .overlay(alignment: .topTrailing) {
            languagePill
                .padding(.top, 14)
                .padding(.trailing, 20)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
                .environmentObject(languageManager)
        }
    }

    // MARK: - Subviews

    private var languagePill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showLanguagePicker = true
        } label: {
            HStack(spacing: 6) {
                if languageManager.current == .system {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                } else {
                    Text(languageManager.current.flag)
                        .font(.system(size: 14))
                }
                Text(languageManager.current.shortLabel)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        Capsule()
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private var illustration: some View {
        Image("mascot-welcome")
            .resizable()
            .scaledToFit()
            .frame(width: 300, height: 300)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Notyfi".notyfiLocalized)
                .font(.notyfi(.largeTitle, weight: .bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text("The most frictionless way to track your spending.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Text("Just write it down.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            OnboardingPrimaryButton(title: "Get Started", action: onGetStarted)

            Spacer().frame(height: 28)

            HStack(spacing: 4) {
                Text("Already have an account?".notyfiLocalized)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSignIn()
                } label: {
                    Text("Sign in".notyfiLocalized)
                }
                .foregroundStyle(NotyfiTheme.brandPrimary)
                .fontWeight(.semibold)
            }
            .font(.notyfi(.subheadline))
        }
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {}, onSignIn: {})
        .environmentObject(LanguageManager())
}
