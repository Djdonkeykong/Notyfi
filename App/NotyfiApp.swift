import SwiftUI
import RevenueCat
import GoogleSignIn

@main
struct NotyfiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ExpenseJournalStore()

    init() {
        Analytics.setup()
        Purchases.configure(withAPIKey: "appl_GngBYbfKxrVpjUFIKMMaGPhkpRr")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "216447990819-4avsmvn10s1uejikf59dlu0taiqpalka.apps.googleusercontent.com"
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
