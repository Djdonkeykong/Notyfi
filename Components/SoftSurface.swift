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
                    .fill(NotelyTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 18, x: 0, y: 10)
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
                    .fill(NotelyTheme.surface)
                    .overlay {
                        Capsule()
                            .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: NotelyTheme.shadow, radius: 16, x: 0, y: 8)
            }
    }
}
