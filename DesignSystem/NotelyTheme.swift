import SwiftUI

enum NotelyTheme {
    static let background = Color(red: 0.972, green: 0.966, blue: 0.962)
    static let surface = Color.white.opacity(0.84)
    static let elevatedSurface = Color(red: 0.992, green: 0.988, blue: 0.984)
    static let surfaceBorder = Color.white.opacity(0.72)
    static let shadow = Color.black.opacity(0.045)
    static let secondaryText = Color.black.opacity(0.58)
    static let tertiaryText = Color.black.opacity(0.38)
    static let accent = Color(red: 0.93, green: 0.72, blue: 0.51)
    static let brandBlue = Color(red: 0.02, green: 0.38, blue: 0.96)
    static let reviewTint = Color(red: 0.90, green: 0.60, blue: 0.29)
}

extension Font {
    static func notely(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
