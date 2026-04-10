import SwiftUI
import UIKit
import Lottie

struct LottieRepresentable: UIViewRepresentable {
    let assetName: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore

        if let asset = NSDataAsset(name: assetName),
           let animation = try? LottieAnimation.from(data: asset.data) {
            view.animation = animation
            view.play()
        }

        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
}
