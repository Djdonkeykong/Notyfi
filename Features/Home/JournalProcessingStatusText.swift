import SwiftUI

struct JournalProcessingStatusText: View {
    private let statuses = ["Checking", "Reading", "Finding", "Thinking"]
    private let loadingDotsDuration: TimeInterval = 0.8
    private let statusDuration: TimeInterval = 2.4
    private let shimmerDuration: TimeInterval = 1.8

    @State private var statusIndex = 0
    @State private var shimmerCycleStart = Date()
    @State private var isShowingLoadingDots = true

    var body: some View {
        ZStack(alignment: .trailing) {
            if isShowingLoadingDots {
                JournalProcessingLoadingDots()
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
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
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }
        }
        .task {
            shimmerCycleStart = Date()
            statusIndex = 0
            isShowingLoadingDots = true

            try? await Task.sleep(for: .seconds(loadingDotsDuration))

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                isShowingLoadingDots = false
            }

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

private struct JournalProcessingLoadingDots: View {
    private let dotSize: CGFloat = 4
    private let dotSpacing: CGFloat = 4
    private let animationDuration: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation) { context in
            HStack(spacing: dotSpacing) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(NotelyTheme.secondaryText.opacity(0.8))
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(dotScale(index: index, timestamp: context.date))
                        .offset(y: dotOffset(index: index, timestamp: context.date))
                }
            }
        }
        .frame(height: 16, alignment: .center)
    }

    private func dotPhase(index: Int, timestamp: Date) -> Double {
        let elapsed = timestamp.timeIntervalSinceReferenceDate
        let progress = elapsed.truncatingRemainder(dividingBy: animationDuration) / animationDuration
        return (progress * 2 * .pi) - (Double(index) * 0.7)
    }

    private func dotScale(index: Int, timestamp: Date) -> CGFloat {
        0.82 + (0.18 * max(0, sin(dotPhase(index: index, timestamp: timestamp))))
    }

    private func dotOffset(index: Int, timestamp: Date) -> CGFloat {
        -2.5 * max(0, sin(dotPhase(index: index, timestamp: timestamp)))
    }
}
