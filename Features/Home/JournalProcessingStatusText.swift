import SwiftUI

struct JournalProcessingStatusText: View {
    private let statuses = ["Checking", "Reading", "Finding", "Thinking"]
    private let statusDuration: TimeInterval = 2.4
    private let shimmerDuration: TimeInterval = 1.8

    @State private var statusIndex = 0
    @State private var shimmerProgress: CGFloat = -1.4

    var body: some View {
        Text(statuses[statusIndex])
            .foregroundStyle(NotelyTheme.secondaryText.opacity(0.45))
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.95),
                            .white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(proxy.size.width * 0.7, 24))
                    .offset(x: shimmerProgress * proxy.size.width)
                    .mask(alignment: .leading) {
                        Text(statuses[statusIndex])
                            .frame(width: proxy.size.width, alignment: .leading)
                    }
                }
                .allowsHitTesting(false)
            }
            .task {
                animateShimmer()
                await rotateStatuses()
            }
    }

    private func animateShimmer() {
        shimmerProgress = -1.4

        withAnimation(
            .linear(duration: shimmerDuration)
            .repeatForever(autoreverses: false)
        ) {
            shimmerProgress = 1.4
        }
    }

    @MainActor
    private func rotateStatuses() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(statusDuration))

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                statusIndex = (statusIndex + 1) % statuses.count
            }
        }
    }
}
