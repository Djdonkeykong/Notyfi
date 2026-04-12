import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let onDateTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                NotyfiMark()

                Spacer()

                SoftCapsule(horizontalPadding: 14, verticalPadding: 11) {
                    Button(action: {
                        Haptics.mediumImpact()
                        onSettingsTap()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: {
                Haptics.mediumImpact()
                onDateTap()
            }) {
                SoftCapsule(horizontalPadding: 20, verticalPadding: 12) {
                    Text(selectedDate.notyfiDayTitle())
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(.primary.opacity(0.84))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotyfiMark: View {
    var body: some View {
        Image("app-mascot-homeTab")
            .resizable()
            .scaledToFit()
            .frame(height: 43)
    }
}

#Preview {
    ZStack {
        NotyfiTheme.background.ignoresSafeArea()
        VStack {
            HomeTopBar(
                selectedDate: Date(),
                onDateTap: {},
                onSettingsTap: {}
            )
            .padding(20)
            Spacer()
        }
    }
}
