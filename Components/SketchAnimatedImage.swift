import SwiftUI

struct SketchAnimatedImage: View {
    let frames: [String]
    var fps: Double = 6

    @State private var index = 0

    var body: some View {
        Image(frames[index])
            .resizable()
            .scaledToFit()
            .onAppear { start() }
    }

    private func start() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            index = (index + 1) % frames.count
        }
    }
}
