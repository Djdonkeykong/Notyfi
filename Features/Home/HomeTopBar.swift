import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let entryCount: Int
    let onDateTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                NotyfiMark()

                Spacer()

                SoftCapsule(horizontalPadding: 14, verticalPadding: 11) {
                    HStack(spacing: 10) {
                        Label {
                            Text("\(entryCount)")
                                .font(.notyfi(.footnote, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.82))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(NotyfiTheme.reviewTint)
                        }

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
            }

            Button(action: {
                Haptics.mediumImpact()
                onDateTap()
            }) {
                SoftCapsule(horizontalPadding: 20, verticalPadding: 12) {
                    Text(selectedDate.notyfiDayTitle())
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.84))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotyfiMark: View {
    var body: some View {
        Image("HomeBrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 43, height: 43)
    }
}

#Preview {
    ZStack {
        NotyfiTheme.background.ignoresSafeArea()
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
