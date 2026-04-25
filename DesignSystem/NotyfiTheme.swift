import SwiftUI
import UIKit

enum NotyfiTheme {
    static let background = adaptiveColor(
        light: UIColor(red: 0.949, green: 0.949, blue: 0.976, alpha: 1),
        dark: UIColor(red: 0.073, green: 0.073, blue: 0.090, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: UIColor(red: 0.992, green: 0.988, blue: 0.984, alpha: 0.96),
        dark: UIColor(red: 0.118, green: 0.125, blue: 0.145, alpha: 0.94)
    )
    static let elevatedSurface = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.998, blue: 0.994, alpha: 1),
        dark: UIColor(red: 0.152, green: 0.160, blue: 0.184, alpha: 1)
    )
    static let inputSurface = adaptiveColor(
        light: UIColor(red: 0.956, green: 0.950, blue: 0.944, alpha: 1),
        dark: UIColor(red: 0.175, green: 0.184, blue: 0.212, alpha: 1)
    )
    static let surfaceBorder = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.72),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let glassOverlay = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.18),
        dark: UIColor.white.withAlphaComponent(0.05)
    )
    static let glassStroke = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.50),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let shadow = adaptiveColor(
        light: UIColor.black.withAlphaComponent(0.045),
        dark: UIColor.black.withAlphaComponent(0.24)
    )
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let shimmerHighlight = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.95),
        dark: UIColor.white.withAlphaComponent(0.36)
    )
    static let accent = Color(red: 1.00, green: 0.66, blue: 0.28)
    static let circleButtonBackground = adaptiveColor(
        light: UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.34, green: 0.34, blue: 0.36, alpha: 1)
    )
    static let brandBlue = adaptiveColor(
        light: UIColor(red: 22.0 / 255.0, green: 45.0 / 255.0, blue: 249.0 / 255.0, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.46, blue: 0.98, alpha: 1)
    )
    static let brandPrimary = adaptiveColor(
        light: UIColor(red: 22.0 / 255.0, green: 45.0 / 255.0, blue: 249.0 / 255.0, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.46, blue: 0.98, alpha: 1)
    )
    static let brandLight = adaptiveColor(
        light: UIColor(red: 242.0 / 255.0, green: 242.0 / 255.0, blue: 249.0 / 255.0, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    )
    static let darkButtonSurface = adaptiveColor(
        light: .black,
        dark: UIColor(red: 0.152, green: 0.160, blue: 0.184, alpha: 1)
    )
    static let reviewTint = Color(red: 1.00, green: 0.60, blue: 0.14)
    static let incomeColor = Color(red: 0.14, green: 0.78, blue: 0.42)
    static let expenseColor = adaptiveColor(
        light: UIColor(red: 0.96, green: 0.22, blue: 0.20, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.42, blue: 0.40, alpha: 1)
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

extension Font {
    static func notyfi(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }
}
