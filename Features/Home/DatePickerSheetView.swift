import SwiftUI

struct DatePickerSheetView: View {
    @Binding var selection: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NotelyTheme.background
                .opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 14) {
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
                .padding(.top, 12)

                SoftSurface(cornerRadius: 30, padding: 10) {
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
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)

                Spacer(minLength: 0)
            }
            .safeAreaPadding(.top, 10)
        }
    }
}

#Preview {
    DatePickerSheetView(selection: .constant(Date()))
}
