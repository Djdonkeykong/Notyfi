import SwiftUI
import AVFoundation

struct LoopingVideoPlayer: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
            view.play(url: url)
        }
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {}
}

final class LoopingPlayerView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspect
        layer.frame = bounds
        self.layer.addSublayer(layer)

        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.play()

        self.player = queuePlayer
        self.playerLayer = layer
    }
}
