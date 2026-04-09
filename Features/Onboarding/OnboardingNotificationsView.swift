import SwiftUI
import UserNotifications

struct OnboardingNotificationsView: View {
    let step: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var isEnabled: Bool = false
    @State private var isRequesting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingNavBar(currentStep: step, totalSteps: totalSteps, onBack: onBack)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    illustration
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

                    Text("Stay on track")
                        .font(.notyfi(.title, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Get a daily nudge to log your spending. People who use reminders build the habit 3x faster.")
                        .font(.notyfi(.body))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .lineSpacing(3)
                        .padding(.bottom, 24)

                    toggleCard
                }
                .padding(.horizontal, 24)
            }

            bottomActions
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var illustration: some View {
        OnboardingIllustration(symbol: "bell.badge.fill", size: 68)
    }

    private var toggleCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NotyfiTheme.brandLight)
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Notifications")
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Daily spending reminders")
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(NotyfiTheme.brandPrimary)
                .onChange(of: isEnabled) { _, newValue in
                    if newValue {
                        requestPermission()
                    }
                }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var bottomActions: some View {
        VStack(spacing: 14) {
            OnboardingPrimaryButton(title: "Continue", action: onNext)
            OnboardingSkipButton(action: onNext)
        }
    }

    // MARK: - Actions

    private func requestPermission() {
        isRequesting = true
        Task { @MainActor in
            var components = DateComponents()
            components.hour = NotyfiReminderSettings.default.hour
            components.minute = NotyfiReminderSettings.default.minute
            let granted = await NotyfiReminderManager.shared.enableReminder(at: components)
            isEnabled = granted
            isRequesting = false
        }
    }
}

#Preview {
    OnboardingNotificationsView(step: 4, totalSteps: 5, onNext: {}, onBack: {})
}
