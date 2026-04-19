import SwiftUI

struct HomeTopBar: View {
    let selectedDate: Date
    let showInsightsBadge: Bool
    let onDateTap: () -> Void
    let onReportsTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        ZStack {
            HStack {
                NotyfiMark()

                Spacer()

                SoftCapsule(horizontalPadding: 8, verticalPadding: 6) {
                    HStack(spacing: 0) {
                        topBarIconButton(
                            systemImage: "chart.line.uptrend.xyaxis",
                            showBadge: showInsightsBadge,
                            action: onReportsTap
                        )

                        Capsule()
                            .fill(.primary.opacity(0.12))
                            .frame(width: 2, height: 22)
                            .padding(.horizontal, 4)

                        topBarIconButton(
                            systemImage: "gearshape.fill",
                            showBadge: false,
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
        showBadge: Bool,
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
                .overlay(alignment: .topTrailing) {
                    if showBadge {
                        Circle()
                            .fill(NotyfiTheme.brandBlue)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct NotyfiMark: View {
    var body: some View {
        Image("app-mascot-homeTab")
            .resizable()
            .scaledToFit()
            .frame(height: 22)
    }
}

#Preview {
    ZStack {
        NotyfiTheme.background.ignoresSafeArea()
        VStack {
            HomeTopBar(
                selectedDate: Date(),
                showInsightsBadge: true,
                onDateTap: {},
                onReportsTap: {},
                onSettingsTap: {}
            )
            .padding(20)
            Spacer()
        }
    }
}
