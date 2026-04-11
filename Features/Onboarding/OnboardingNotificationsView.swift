import SwiftUI
import UserNotifications

struct OnboardingNotificationsView: View {
    @State private var isEnabled: Bool = false
    @State private var frequency: ReminderFrequency = .regular

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Image("mascot-notifications")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                Text("Stay on track".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Get a daily nudge to log your spending. People who use reminders build the habit 3x faster.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                toggleCard

                if isEnabled {
                    frequencyCard
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.25), value: isEnabled)
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
                Text("Enable Notifications".notyfiLocalized)
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                Text("Daily spending reminders".notyfiLocalized)
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
                    } else {
                        Task { await NotyfiReminderManager.shared.disableReminder() }
                    }
                }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var frequencyCard: some View {
        VStack(spacing: 20) {
            ReminderFrequencySlider(selection: $frequency)
                .onChange(of: frequency) { _, newValue in
                    Task { await NotyfiReminderManager.shared.updateFrequency(newValue) }
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func requestPermission() {
        Task { @MainActor in
            let granted = await NotyfiReminderManager.shared.enableReminders(frequency: frequency)
            isEnabled = granted
        }
    }
}

// MARK: - Step Slider

private struct ReminderFrequencySlider: View {
    @Binding var selection: ReminderFrequency

    private let steps = ReminderFrequency.allCases
    private let thumbSize: CGFloat = 28
    private let trackHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width - thumbSize
            let stepWidth = trackWidth / CGFloat(steps.count - 1)
            let thumbX = CGFloat(selection.rawValue) * stepWidth

            VStack(spacing: 14) {
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: trackHeight)
                        .padding(.horizontal, thumbSize / 2)

                    // Filled portion
                    Capsule()
                        .fill(NotyfiTheme.brandPrimary.opacity(0.25))
                        .frame(width: thumbX + thumbSize / 2, height: trackHeight)
                        .padding(.leading, thumbSize / 2)

                    // Step dots
                    ForEach(steps) { step in
                        let x = CGFloat(step.rawValue) * stepWidth + thumbSize / 2
                        Circle()
                            .fill(step.rawValue <= selection.rawValue
                                  ? NotyfiTheme.brandPrimary.opacity(0.4)
                                  : Color.primary.opacity(0.15))
                            .frame(width: 6, height: 6)
                            .offset(x: x - 3)
                    }

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                        .offset(x: thumbX)
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: selection)
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = max(0, min(trackWidth, value.location.x - thumbSize / 2))
                            let raw = Int((x / stepWidth).rounded())
                            let clamped = max(0, min(steps.count - 1, raw))
                            if let newStep = ReminderFrequency(rawValue: clamped), newStep != selection {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selection = newStep
                            }
                        }
                )

                // Labels
                HStack(spacing: 0) {
                    ForEach(steps) { step in
                        Text(step.label)
                            .font(.notyfi(.caption))
                            .foregroundStyle(step == selection
                                             ? NotyfiTheme.brandPrimary
                                             : NotyfiTheme.secondaryText)
                            .fontWeight(step == selection ? .semibold : .regular)
                            .frame(maxWidth: .infinity)
                            .animation(.easeInOut(duration: 0.15), value: selection)
                    }
                }
            }
        }
        .frame(height: 62)
    }
}

extension ReminderFrequency: Identifiable {
    var id: Int { rawValue }
}

#Preview {
    NavigationStack {
        OnboardingNotificationsView()
    }
}
