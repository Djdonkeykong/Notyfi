import SwiftUI

struct SketchAnimatedImage: View {
    let frames: [String]
    var fps: Double = 6

    @State private var index = 0
    @State private var timer: Timer?

    var body: some View {
        Image(frames[index])
            .resizable()
            .scaledToFit()
            .onAppear { start() }
            .onDisappear { stop() }
    }

    private func start() {
        stop()
        // Sync phase to wall clock so any new instance showing the same
        // frames starts on the correct frame rather than always frame 0.
        index = Int(Date().timeIntervalSince1970 * fps) % frames.count
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            index = (index + 1) % frames.count
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}
