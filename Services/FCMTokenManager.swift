import FirebaseMessaging
import Foundation

final class FCMTokenManager: NSObject, MessagingDelegate {
    static let shared = FCMTokenManager()

    // Called by Firebase when a new/refreshed FCM token is available
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { await uploadToken(fcmToken) }
    }

    // Call this after the user authenticates to ensure the token is stored
    func uploadCurrentTokenIfAvailable() {
        Task {
            guard let token = try? await Messaging.messaging().token() else { return }
            await uploadToken(token)
        }
    }

    private func uploadToken(_ token: String) async {
        guard let userID = SupabaseService.client.auth.currentSession?.user.id else { return }
        do {
            try await SupabaseService.client
                .from("device_tokens")
                .upsert(
                    DeviceTokenPayload(userID: userID, token: token),
                    onConflict: "user_id,token"
                )
                .execute()
        } catch {
            // Silent failure — will retry on next launch or token refresh
        }
    }
}

private struct DeviceTokenPayload: Encodable {
    let userID: UUID
    let token: String
    let platform = "ios"

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token
        case platform
    }
}
