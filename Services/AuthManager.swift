import Foundation
import Supabase
import Auth
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var userEmail: String? = nil
    @Published private(set) var userDisplayName: String? = nil

    private var authStateTask: Task<Void, Never>?

    init() {
        // Subscribe to Supabase auth state changes so session
        // restores automatically on re-launch (SDK handles token refresh).
        authStateTask = Task { [weak self] in
            for await (_, session) in SupabaseService.client.auth.authStateChanges {
                guard let self else { return }
                self.isAuthenticated = session != nil
                self.isReady = true
                self.userEmail = session?.user.email
                self.userDisplayName = session?.user.userMetadata["full_name"]?.stringValue
                    ?? session?.user.userMetadata["name"]?.stringValue
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Apple Sign In

    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }

        let rawNonce = randomNonce()
        let hashedNonce = sha256(rawNonce)

        let credential = try await requestAppleCredential(nonce: hashedNonce)

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }

        try await SupabaseService.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString,
                nonce: rawNonce
            )
        )
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw AuthError.googleSignInFailed
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: root,
                hint: nil,
                additionalScopes: nil
            )
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingIdentityToken
            }
            try await SupabaseService.client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            throw AuthError.googleSignInCancelled
        }
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await SupabaseService.client.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await SupabaseService.client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await SupabaseService.client.auth.signOut()
            isAuthenticated = false
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        // Supabase does not expose a client-side delete-user API on the anon key.
        // The recommended pattern is an Edge Function that calls admin.deleteUser()
        // with the service_role key. For now we sign the user out locally so they
        // are not stuck in the app; the Edge Function call will be wired in Phase 5.
        try? await SupabaseService.client.auth.signOut()
        isAuthenticated = false
    }

    // MARK: - Apple Sign In Helpers

    private func requestAppleCredential(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce

            let delegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            // Keep delegate alive for the duration of the request.
            AppleSignInDelegate.activeDelegate = delegate

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.performRequests()
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        assert(result == errSecSuccess, "SecRandomCopyBytes failed")
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingIdentityToken
    case appleSignInCancelled
    case appleSignInFailed(Error)
    case googleSignInCancelled
    case googleSignInFailed

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "error.auth.missingToken".notyfiLocalized
        case .appleSignInCancelled, .googleSignInCancelled:
            return "error.auth.cancelled".notyfiLocalized
        case .appleSignInFailed(let error):
            return error.localizedDescription
        case .googleSignInFailed:
            return "error.auth.googleFailed".notyfiLocalized
        }
    }

    var isCancelled: Bool {
        switch self {
        case .appleSignInCancelled, .googleSignInCancelled: return true
        default: return false
        }
    }
}

// MARK: - ASAuthorizationController Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    // Retained statically so ARC doesn't release it before the callback fires.
    static var activeDelegate: AppleSignInDelegate?

    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { Self.activeDelegate = nil }
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(credential))
        } else {
            completion(.failure(AuthError.missingIdentityToken))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { Self.activeDelegate = nil }
        let asError = error as? ASAuthorizationError
        if asError?.code == .canceled {
            completion(.failure(AuthError.appleSignInCancelled))
        } else {
            completion(.failure(AuthError.appleSignInFailed(error)))
        }
    }
}
