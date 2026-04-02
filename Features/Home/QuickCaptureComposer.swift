import SwiftUI

struct QuickCaptureComposer: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SoftSurface(cornerRadius: 30, padding: 18) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Coffee 49 kr", text: $text, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.notely(.body))
                        .foregroundStyle(.primary.opacity(0.84))
                        .submitLabel(.done)
                        .focused($isFocused)
                        .onSubmit(onSubmit)

                    Text("Type it naturally. Notely keeps the structure in the background.")
                        .font(.notely(.caption))
                        .foregroundStyle(NotelyTheme.secondaryText)
                }

                Button(action: {
                    onSubmit()
                    isFocused = false
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isEmpty ? NotelyTheme.tertiaryText : .white)
                        .frame(width: 42, height: 42)
                        .background {
                            Circle()
                                .fill(isEmpty ? NotelyTheme.elevatedSurface : NotelyTheme.reviewTint)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack {
            Spacer()
            QuickCaptureComposer(text: .constant("Coffee 49"), onSubmit: {})
        }
    }
}
