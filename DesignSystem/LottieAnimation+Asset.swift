import Lottie

extension LottieAnimation {
    /// Loads a Lottie animation from an NSDataAsset in the main asset catalog.
    /// Animations must be stored as Data Sets inside Assets.xcassets.
    static func fromAsset(_ name: String) -> LottieAnimation? {
        guard let asset = NSDataAsset(name: name),
              let animation = try? LottieAnimation.from(data: asset.data)
        else { return nil }
        return animation
    }
}
