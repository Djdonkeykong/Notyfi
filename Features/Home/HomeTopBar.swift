import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let entryCount: Int
    let onDateTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                NotelyMark()

                Spacer()

                SoftCapsule(horizontalPadding: 14, verticalPadding: 11) {
                    HStack(spacing: 10) {
                        Label {
                            Text("\(entryCount)")
                                .font(.notely(.footnote, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.82))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(NotelyTheme.reviewTint)
                        }

                        Button(action: onSettingsTap) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.82))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onDateTap) {
                SoftCapsule(horizontalPadding: 22, verticalPadding: 13) {
                    Text(selectedDate.notelyDayTitle())
                        .font(.notely(.body, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.84))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotelyMark: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("N")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.52))
                .rotationEffect(.degrees(-18))

            Image(systemName: "scribble")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary.opacity(0.55))
                .offset(x: 7, y: 12)
        }
        .frame(width: 28, height: 28, alignment: .topLeading)
        .padding(.leading, 2)
    }
}

#Preview {
    ZStack {
        NotelyTheme.background.ignoresSafeArea()
        VStack {
            HomeTopBar(
                selectedDate: Date(),
                entryCount: 2,
                onDateTap: {},
                onSettingsTap: {}
            )
            .padding(20)
            Spacer()
        }
    }
}
