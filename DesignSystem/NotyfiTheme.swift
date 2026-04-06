import SwiftUI

enum NotyfiTheme {
    static let background = Color(red: 0.972, green: 0.966, blue: 0.962)
    static let backgroundHighlight = Color.white.opacity(0.88)
    static let backgroundMist = Color(red: 0.92, green: 0.95, blue: 1.0).opacity(0.9)
    static let backgroundWarmGlow = Color(red: 1.0, green: 0.91, blue: 0.80).opacity(0.72)
    static let backgroundCoolGlow = Color(red: 0.83, green: 0.90, blue: 1.0).opacity(0.55)
    static let surface = Color.white.opacity(0.18)
    static let elevatedSurface = Color.white.opacity(0.24)
    static let surfaceBorder = Color.white.opacity(0.42)
    static let innerHighlight = Color.white.opacity(0.26)
    static let shadow = Color.black.opacity(0.08)
    static let secondaryText = Color.black.opacity(0.58)
    static let tertiaryText = Color.black.opacity(0.38)
    static let accent = Color(red: 0.93, green: 0.72, blue: 0.51)
    static let brandBlue = Color(red: 0.02, green: 0.38, blue: 0.96)
    static let reviewTint = Color(red: 0.90, green: 0.60, blue: 0.29)
}

struct NotyfiBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NotyfiTheme.backgroundHighlight,
                    NotyfiTheme.background,
                    Color(red: 0.95, green: 0.94, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    NotyfiTheme.backgroundWarmGlow,
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 340
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [
                    NotyfiTheme.backgroundCoolGlow,
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 360
            )
            .blendMode(.plusLighter)

            LinearGradient(
                colors: [
                    NotyfiTheme.backgroundMist.opacity(0.8),
                    .clear,
                    Color.white.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

extension Font {
    static func notyfi(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
