import SwiftUI

struct SoftSurface<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassPanel(cornerRadius: cornerRadius)
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
            .glassCapsule()
    }
}

struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassPanel(cornerRadius: cornerRadius, material: .regularMaterial)
    }
}

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    var material: Material = .ultraThinMaterial
    var tintOpacity: Double = 0.9
    var shadowRadius: CGFloat = 24
    var shadowY: CGFloat = 12

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.26 * tintOpacity),
                                    NotyfiTheme.surface.opacity(0.9),
                                    Color.white.opacity(0.08 * tintOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.72),
                                    NotyfiTheme.surfaceBorder,
                                    Color.white.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    NotyfiTheme.innerHighlight.opacity(0.95),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(1)
                        .mask(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                }
                .shadow(color: NotyfiTheme.shadow, radius: shadowRadius, x: 0, y: shadowY)
                .shadow(color: Color.white.opacity(0.18), radius: 10, x: 0, y: -2)
        }
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    var material: Material = .ultraThinMaterial

    func body(content: Content) -> some View {
        content.background {
            Capsule(style: .continuous)
                .fill(material)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    NotyfiTheme.surface,
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.74),
                                    NotyfiTheme.surfaceBorder,
                                    Color.white.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: NotyfiTheme.shadow, radius: 18, x: 0, y: 8)
        }
    }
}

private struct GlassCircleModifier: ViewModifier {
    var material: Material = .ultraThinMaterial

    func body(content: Content) -> some View {
        content.background {
            Circle()
                .fill(material)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    NotyfiTheme.surface,
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.74),
                                    NotyfiTheme.surfaceBorder,
                                    Color.white.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: NotyfiTheme.shadow, radius: 18, x: 0, y: 10)
        }
    }
}

extension View {
    func glassPanel(
        cornerRadius: CGFloat,
        material: Material = .ultraThinMaterial,
        tintOpacity: Double = 0.9,
        shadowRadius: CGFloat = 24,
        shadowY: CGFloat = 12
    ) -> some View {
        modifier(
            GlassPanelModifier(
                cornerRadius: cornerRadius,
                material: material,
                tintOpacity: tintOpacity,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }

    func glassCapsule(material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCapsuleModifier(material: material))
    }

    func glassCircle(diameter _: CGFloat, material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCircleModifier(material: material))
    }
}
