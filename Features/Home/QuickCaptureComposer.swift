import SwiftUI

struct QuickCaptureComposer: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            TextField("Start typing your money notes...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.notely(.body))
                .foregroundStyle(.primary.opacity(0.74))
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit {
                    onSubmit()
                }

            if !isEmpty {
                Button(action: {
                    onSubmit()
                    isFocused = false
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background {
                            Circle()
                                .fill(NotelyTheme.reviewTint)
                        }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEmpty)
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack(alignment: .leading) {
            QuickCaptureComposer(text: .constant("Coffee 49"), onSubmit: {})
                .padding(20)
            Spacer()
        }
    }
}
