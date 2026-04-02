import SwiftUI

struct JournalProcessingStatusText: View {
    private let statuses = ["Checking", "Reading", "Finding", "Thinking"]
    private let tickDuration: TimeInterval = 0.85

    var body: some View {
        TimelineView(.periodic(from: .now, by: tickDuration)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let index = Int(time / tickDuration) % statuses.count
            let phase = (time.truncatingRemainder(dividingBy: tickDuration)) / tickDuration
            let pulse = 0.45 + (0.5 * sin(.pi * phase))

            Text(statuses[index])
                .id(index)
                .opacity(pulse)
                .animation(.easeInOut(duration: 0.2), value: index)
        }
    }
}
