import SwiftUI

struct SoftSurface<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 18, x: 0, y: 10)
            }
    }
}

struct SoftCapsule<Content: View>: View {
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                Capsule()
                    .fill(NotyfiTheme.surface)
                    .overlay {
                        Capsule()
                            .stroke(NotyfiTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow, radius: 16, x: 0, y: 8)
            }
    }
}

struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(NotyfiTheme.glassOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(NotyfiTheme.glassStroke, lineWidth: 1)
                    }
                    .shadow(color: NotyfiTheme.shadow.opacity(0.9), radius: 24, x: 0, y: 10)
            }
    }
}
