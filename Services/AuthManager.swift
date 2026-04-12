import Foundation
import Supabase
import Auth
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import OSLog
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var userEmail: String? = nil
    @Published private(set) var userDisplayName: String? = nil

    private let logger = Logger(subsystem: "com.djdonkeykong.notely", category: "auth")
    private var authStateTask: Task<Void, Never>?

    init() {
        // Subscribe to Supabase auth state changes so session
        // restores automatically on re-launch (SDK handles token refresh).
        authStateTask = Task { [weak self] in
            for await (_, session) in await SupabaseService.client.auth.authStateChanges {
                guard let self else { return }
                self.applyAuthState(session: session)
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
        logger.log("Starting Apple sign-in")

        let rawNonce = randomNonce()
        let hashedNonce = sha256(rawNonce)

        let credential = try await requestAppleCredential(nonce: hashedNonce)

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }

        let session = try await SupabaseService.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString,
                nonce: rawNonce
            )
        )
        try await applyVerifiedAuthState(
            preferredSession: session,
            context: "Apple sign-in"
        )
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        logger.log("Starting Google sign-in")

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            logger.error("Google sign-in failed before presentation: missing key window")
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
            let session = try await SupabaseService.client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )
            try await applyVerifiedAuthState(
                preferredSession: session,
                context: "Google sign-in"
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            logger.log("Google sign-in cancelled by user")
            throw AuthError.googleSignInCancelled
        } catch {
            logger.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Email OTP

    func sendOTP(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        logger.log("Sending email OTP to \(email, privacy: .public)")
        try await SupabaseService.client.auth.signInWithOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        logger.log("Verifying email OTP for \(email, privacy: .public)")
        try await SupabaseService.client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
        try await applyVerifiedAuthState(
            preferredSession: SupabaseService.client.auth.currentSession,
            context: "Email OTP verification"
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

    private func applyVerifiedAuthState(
        preferredSession: Session?,
        context: String
    ) async throws {
        if let preferredSession {
            logger.log("\(context, privacy: .public) completed with immediate session")
            applyAuthState(session: preferredSession)
            return
        }

        if let currentSession = SupabaseService.client.auth.currentSession {
            logger.log("\(context, privacy: .public) found current cached session")
            applyAuthState(session: currentSession)
            return
        }

        do {
            let persistedSession = try await SupabaseService.client.auth.session
            logger.log("\(context, privacy: .public) recovered persisted session")
            applyAuthState(session: persistedSession)
        } catch {
            logger.error("\(context, privacy: .public) finished without an active Supabase session: \(error.localizedDescription, privacy: .public)")
            throw AuthError.sessionNotEstablished
        }
    }

    private func applyAuthState(session: Session?) {
        isAuthenticated = session != nil
        isReady = true
        userEmail = session?.user.email
        userDisplayName = session?.user.userMetadata["full_name"]?.stringValue
            ?? session?.user.userMetadata["name"]?.stringValue
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingIdentityToken
    case appleSignInCancelled
    case appleSignInFailed(Error)
    case googleSignInCancelled
    case googleSignInFailed
    case sessionNotEstablished

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
        case .sessionNotEstablished:
            return "Sign-in succeeded, but no session was established. Check the Xcode console for auth logs."
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
