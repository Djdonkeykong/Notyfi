import SwiftUI
import UserNotifications
import Lottie

struct OnboardingNotificationsView: View {
    @State private var isEnabled: Bool = false
    @State private var isRequesting: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                LottieView(animation: .fromAsset("mascot-reminder"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .padding(.vertical, 24)

                Text("Stay on track")
                    .font(.notyfi(.title2, weight: .bold))
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
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
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
                    if newValue { requestPermission() }
                }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

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
    NavigationStack {
        OnboardingNotificationsView()
    }
}
