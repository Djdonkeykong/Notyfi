import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NotelyTheme.background.opacity(0.72),
                    Color.white.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button("Today") {
                        selection = Date()
                    }
                    .font(.notely(.body, weight: .semibold))
                    .foregroundStyle(.blue)

                    Spacer()

                    Text(selection.formatted(.dateTime.month(.abbreviated).year()))
                        .font(.notely(.headline, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.84))

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .font(.notely(.body, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)

                GlassSurface(cornerRadius: 32, padding: 16) {
                    DatePicker(
                        "",
                        selection: $selection,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(NotelyTheme.reviewTint)
                }
                .padding(.horizontal, 18)

                Spacer(minLength: 0)
            }
            .safeAreaPadding(.top, 18)
        }
    }
}

#Preview {
    DatePickerSheetView(selection: .constant(Date()))
}
