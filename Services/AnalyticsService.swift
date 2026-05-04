import Foundation
import PostHog

enum Analytics {
    private static let apiKey = "phc_rCgxrAFciEba3qovWdbRnEWWmQ37Q3omJ67mQpC2DtHa"
    private static let host = "https://eu.i.posthog.com"

    static func setup() {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

    static func capture(_ event: String, properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: properties.isEmpty ? nil : properties)
    }

    static func identify(userID: String, email: String?, name: String?) {
        var props: [String: Any] = [:]
        if let email { props["email"] = email }
        if let name { props["name"] = name }
        PostHogSDK.shared.identify(userID, userProperties: props.isEmpty ? nil : props)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }
}
