import SwiftUI

struct SketchAnimatedImage: View {
    let frames: [String]
    var fps: Double = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate * fps) % frames.count
            Image(frames[index])
                .resizable()
                .scaledToFit()
        }
    }
}
