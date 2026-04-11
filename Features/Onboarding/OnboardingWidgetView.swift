import SwiftUI

struct OnboardingWidgetView: View {
    @State private var screen: WidgetScreen = .home

    private enum WidgetScreen: CaseIterable {
        case home, lock

        var label: String {
            switch self {
            case .home: return "Home Screen"
            case .lock: return "Lock Screen"
            }
        }

        var imageName: String {
            switch self {
            case .home: return "widget-preview-home"
            case .lock: return "widget-preview-lock"
            }
        }

        var tint: Color {
            switch self {
            case .home: return NotyfiTheme.brandPrimary
            case .lock: return NotyfiTheme.brandPrimary
            }
        }

        var steps: [(Int, String)] {
            switch self {
            case .home:
                return [
                    (1, "Long press anywhere on your Home Screen"),
                    (2, "Tap the \"+\" button in the top left corner"),
                    (3, "Scroll down, tap Notyfi, then add a widget"),
                    (4, "Tap the widget any time to open the app")
                ]
            case .lock:
                return [
                    (1, "Long press anywhere on your Lock Screen"),
                    (2, "Tap \"Customize\" at the bottom, then \"Add widgets\""),
                    (3, "Scroll down, tap Notyfi, then add a widget")
                ]
            }
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                title
                    .padding(.bottom, 24)

                previewImage
                    .padding(.bottom, 20)

                screenToggle
                    .padding(.bottom, 28)

                stepsList
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

    private var title: some View {
        Text("Add the Notyfi widget to stay on top of your spending — every single day.".notyfiLocalized)
            .font(.notyfi(.title2, weight: .bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var previewImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(screen == .home
                      ? Color(red: 0.82, green: 0.88, blue: 0.95)
                      : Color(red: 0.88, green: 0.84, blue: 0.95))

            if UIImage(named: screen.imageName) != nil {
                Image(screen.imageName)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.on.square.dashed")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.primary.opacity(0.25))
                    Text("Widget preview image\ncoming soon")
                        .font(.notyfi(.caption))
                        .foregroundStyle(Color.primary.opacity(0.30))
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .animation(.easeInOut(duration: 0.25), value: screen)
    }

    private var screenToggle: some View {
        HStack(spacing: 0) {
            ForEach(WidgetScreen.allCases, id: \.label) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) { screen = option }
                } label: {
                    Text(option.label.notyfiLocalized)
                        .font(.notyfi(.subheadline, weight: .semibold))
                        .foregroundStyle(screen == option ? .white : NotyfiTheme.brandPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if screen == option {
                                Capsule()
                                    .fill(NotyfiTheme.brandPrimary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(.white)
                .overlay {
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var stepsList: some View {
        VStack(spacing: 16) {
            ForEach(screen.steps, id: \.0) { number, text in
                WidgetStep(number: number, text: text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: screen)
    }
}

private struct WidgetStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(NotyfiTheme.brandPrimary)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(text.notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingWidgetView()
    }
}
