import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let onDateTap: () -> Void
    let onReportsTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                NotyfiMark()

                Spacer()

                SoftCapsule(horizontalPadding: 8, verticalPadding: 7) {
                    HStack(spacing: 0) {
                        topBarIconButton(
                            systemImage: "chart.line.uptrend.xyaxis",
                            action: onReportsTap
                        )

                        Rectangle()
                            .fill(NotyfiTheme.surfaceBorder.opacity(0.75))
                            .frame(width: 1, height: 18)
                            .padding(.horizontal, 2)

                        topBarIconButton(
                            systemImage: "gearshape.fill",
                            action: onSettingsTap
                        )
                    }
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

private extension HomeTopBar {
    func topBarIconButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptics.mediumImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                onReportsTap: {},
                onSettingsTap: {}
            )
            .padding(20)
            Spacer()
        }
    }
}
