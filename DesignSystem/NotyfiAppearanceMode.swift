import SwiftUI

enum NotyfiAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "notyfi.appearance.mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System".notyfiLocalized
        case .light:
            return "Light".notyfiLocalized
        case .dark:
            return "Dark".notyfiLocalized
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
