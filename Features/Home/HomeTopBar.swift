import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let onDateTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Text("Notely")
                    .font(.notely(.headline, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))

                Spacer()

                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background {
                            Circle()
                                .fill(NotelyTheme.surface)
                                .overlay {
                                    Circle()
                                        .stroke(NotelyTheme.surfaceBorder, lineWidth: 1)
                                }
                                .shadow(color: NotelyTheme.shadow, radius: 14, x: 0, y: 8)
                        }
                }
                .buttonStyle(.plain)
            }

            Button(action: onDateTap) {
                SoftCapsule(horizontalPadding: 18, verticalPadding: 13) {
                    HStack(spacing: 8) {
                        Text(selectedDate.notelyDayTitle())
                            .font(.notely(.body, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.84))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotelyTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack {
            HomeTopBar(selectedDate: Date(), onDateTap: {}, onSettingsTap: {})
                .padding(20)
            Spacer()
        }
    }
}

