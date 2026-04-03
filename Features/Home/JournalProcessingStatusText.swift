import SwiftUI

struct JournalProcessingStatusText: View {
    private let statuses = ["Checking", "Reading", "Finding", "Thinking"]
    private let statusDuration: TimeInterval = 2.4
    private let shimmerDuration: TimeInterval = 1.8

    @State private var statusIndex = 0
    @State private var shimmerCycleStart = Date()

    var body: some View {
        TimelineView(.animation) { context in
            ZStack(alignment: .leading) {
                shimmeredStatusText(
                    statuses[statusIndex],
                    timestamp: context.date
                )
                .id(statusIndex)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
            }
            .clipped()
        }
        .task {
            shimmerCycleStart = Date()
            await rotateStatuses()
        }
    }

    private func shimmeredStatusText(_ status: String, timestamp: Date) -> some View {
        Text(status)
            .foregroundStyle(NotelyTheme.secondaryText.opacity(0.45))
            .overlay {
                GeometryReader { proxy in
                    let elapsed = timestamp.timeIntervalSince(shimmerCycleStart)
                    let phase = elapsed.truncatingRemainder(dividingBy: shimmerDuration) / shimmerDuration
                    let shimmerProgress = -1.4 + (phase * 2.8)

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
                        Text(status)
                            .frame(width: proxy.size.width, alignment: .leading)
                    }
                }
                .allowsHitTesting(false)
            }
    }

    @MainActor
    private func rotateStatuses() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(statusDuration))

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                statusIndex = (statusIndex + 1) % statuses.count
            }
        }
    }
}
