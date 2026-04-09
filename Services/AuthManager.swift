import Foundation
import Supabase
import Auth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false

    // Set by signUpWithEmail when Supabase requires email confirmation.
    // UI can read this to show a "check your inbox" message instead of an error.
    @Published private(set) var pendingEmailConfirmation: Bool = false

    private var authStateTask: Task<Void, Never>?

    init() {
        // Subscribe to Supabase auth state changes so session
        // restores automatically on re-launch (SDK handles token refresh).
        authStateTask = Task { [weak self] in
            for await (_, session) in SupabaseService.client.auth.authStateChanges {
                guard let self else { return }
                self.isAuthenticated = session != nil
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

    // MARK: - Email

    func signUpWithEmail(_ email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        pendingEmailConfirmation = false

        let response = try await SupabaseService.client.auth.signUp(
            email: email,
            password: password
        )

        // If session is nil the user needs to confirm their email first.
        if response.session == nil {
            pendingEmailConfirmation = true
        }
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await SupabaseService.client.auth.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            try? await SupabaseService.client.auth.signOut()
            isAuthenticated = false
        }
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

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple Sign In failed: missing identity token."
        case .appleSignInCancelled:
            return "Sign in cancelled."
        case .appleSignInFailed(let error):
            return error.localizedDescription
        }
    }

    var isCancelled: Bool {
        if case .appleSignInCancelled = self { return true }
        return false
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
