import SwiftUI
import UIKit

enum NotyfiTheme {
    static let background = adaptiveColor(
        light: UIColor(red: 0.951, green: 0.953, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.073, green: 0.078, blue: 0.090, alpha: 1)
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
    static let accent = Color(red: 0.93, green: 0.72, blue: 0.51)
    static let circleButtonBackground = adaptiveColor(
        light: UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1)
    )
    static let brandBlue = Color(red: 0.02, green: 0.38, blue: 0.96)
    static let brandPrimary = Color(red: 0, green: 0, blue: 254.0 / 255.0)
    static let brandLight = Color(red: 242.0 / 255.0, green: 243.0 / 255.0, blue: 245.0 / 255.0)
    static let reviewTint = Color(red: 0.90, green: 0.60, blue: 0.29)
    static let incomeColor = Color(red: 0.28, green: 0.71, blue: 0.45)
    static let expenseColor = Color(red: 0.90, green: 0.36, blue: 0.34)

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
