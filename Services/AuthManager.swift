import Foundation
import RevenueCat
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
                self.setDebugMessage(
                    "Auth state changed. session=\(session != nil ? "yes" : "no") user=\(session?.user.email ?? "nil")"
                )
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
        setDebugMessage("Starting Apple sign-in")

        let rawNonce = randomNonce()
        let hashedNonce = sha256(rawNonce)

        let credential = try await requestAppleCredential(nonce: hashedNonce)
        setDebugMessage("Apple credential received")

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            setDebugMessage("Apple sign-in failed: missing identity token")
            throw AuthError.missingIdentityToken
        }

        let authorizationCode = credential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        setDebugMessage("Exchanging Apple token with Supabase")
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

        if let code = authorizationCode {
            try? await SupabaseService.client.functions.invoke(
                "store-apple-token",
                options: FunctionInvokeOptions(body: ["authorizationCode": code])
            )
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        setDebugMessage("Starting Google sign-in")

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            setDebugMessage("Google sign-in failed: missing key window")
            throw AuthError.googleSignInFailed
        }

        do {
            setDebugMessage("Presenting Google sign-in")
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: root,
                hint: nil,
                additionalScopes: nil
            )
            setDebugMessage("Google credential received")
            guard let idToken = result.user.idToken?.tokenString else {
                setDebugMessage("Google sign-in failed: missing identity token")
                throw AuthError.missingIdentityToken
            }
            setDebugMessage("Exchanging Google token with Supabase")
            let session = try await SupabaseService.client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )
            try await applyVerifiedAuthState(
                preferredSession: session,
                context: "Google sign-in"
            )
        } catch let error as GIDSignInError where error.code == .canceled {
            setDebugMessage("Google sign-in cancelled by user")
            throw AuthError.googleSignInCancelled
        } catch {
            setDebugMessage("Google sign-in failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Email OTP

    func sendOTP(email: String, shouldCreateUser: Bool = true) async throws {
        isLoading = true
        defer { isLoading = false }
        if email.lowercased() == "appstore@notyfi.app" {
            setDebugMessage("Review account detected — skipping OTP send")
            return
        }
        setDebugMessage("Sending email OTP to \(email) (shouldCreateUser=\(shouldCreateUser))")
        try await SupabaseService.client.auth.signInWithOTP(
            email: email,
            shouldCreateUser: shouldCreateUser
        )
        setDebugMessage("OTP email sent to \(email)")
    }

    func verifyOTP(email: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        if email.lowercased() == "appstore@notyfi.app" && token == "123456" {
            setDebugMessage("Review account bypass — signing in with password")
            let session = try await SupabaseService.client.auth.signIn(
                email: email,
                password: token
            )
            try await applyVerifiedAuthState(
                preferredSession: session,
                context: "Review account sign-in"
            )
            return
        }
        setDebugMessage("Verifying email OTP for \(email)")
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

    // MARK: - New-User Detection

    /// Returns true if the authenticated user has no onboarding_completed_at set in
    /// public.users — meaning they created an account without going through onboarding.
    /// Safe to call after any sign-in; returns false on network error to avoid blocking.
    func isNewUserWithoutOnboarding() async -> Bool {
        // currentSession may not be cached yet if authStateChanges fired before the
        // SDK finished persisting the session (common with email OTP). Fall back to
        // the async session fetch so we never miss a new-user redirect.
        let userID: UUID
        if let id = SupabaseService.client.auth.currentSession?.user.id {
            userID = id
        } else if let session = try? await SupabaseService.client.auth.session {
            userID = session.user.id
        } else {
            return false
        }
        do {
            struct OnboardingStatusRow: Decodable {
                let onboardingCompletedAt: Date?
                enum CodingKeys: String, CodingKey {
                    case onboardingCompletedAt = "onboarding_completed_at"
                }
            }
            let rows: [OnboardingStatusRow] = try await SupabaseService.client
                .from("users")
                .select("onboarding_completed_at")
                .eq("id", value: userID.uuidString.lowercased())
                .execute()
                .value
            // Empty rows = trigger hasn't run yet = treat as new user
            return rows.isEmpty || rows.first?.onboardingCompletedAt == nil
        } catch {
            logger.error("Onboarding status check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        Analytics.reset()
        try? await SupabaseService.client.auth.signOut()
        try? await Purchases.shared.logOut()
        isAuthenticated = false
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        do {
            try await SupabaseService.client.functions.invoke("delete-account")
        } catch {
            logger.error("delete-account edge function failed: \(error.localizedDescription, privacy: .public)")
            throw AuthError.deleteFailed
        }
        Analytics.reset()
        try? await SupabaseService.client.auth.signOut()
        try? await Purchases.shared.logOut()
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
        precondition(result == errSecSuccess, "SecRandomCopyBytes failed")
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
            setDebugMessage("\(context) completed with immediate session")
            applyAuthState(session: preferredSession)
            return
        }

        if let currentSession = SupabaseService.client.auth.currentSession {
            setDebugMessage("\(context) found current cached session")
            applyAuthState(session: currentSession)
            return
        }

        do {
            let persistedSession = try await SupabaseService.client.auth.session
            setDebugMessage("\(context) recovered persisted session")
            applyAuthState(session: persistedSession)
        } catch {
            setDebugMessage("\(context) finished without an active Supabase session: \(error.localizedDescription)")
            throw AuthError.sessionNotEstablished
        }
    }

    var supabaseUserID: String? {
        SupabaseService.client.auth.currentSession?.user.id.uuidString
    }

    var supabaseUserEmail: String? {
        SupabaseService.client.auth.currentSession?.user.email
    }

    private func applyAuthState(session: Session?) {
        isAuthenticated = session != nil
        isReady = true
        userEmail = session?.user.email
        userDisplayName = session?.user.userMetadata["full_name"]?.stringValue
            ?? session?.user.userMetadata["name"]?.stringValue
        setDebugMessage(
            "applyAuthState: authenticated=\(session != nil ? "yes" : "no") user=\(session?.user.email ?? "nil")"
        )
        if let userID = session?.user.id.uuidString {
            Task { try? await Purchases.shared.logIn(userID) }
            Analytics.identify(
                userID: userID,
                email: session?.user.email,
                name: session?.user.userMetadata["full_name"]?.stringValue
                    ?? session?.user.userMetadata["name"]?.stringValue
            )
        }
    }

    private func setDebugMessage(_ message: String) {
        logger.log("\(message, privacy: .private)")
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
    case deleteFailed

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
        case .deleteFailed:
            return "Account deletion failed. Please try again or contact support."
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
