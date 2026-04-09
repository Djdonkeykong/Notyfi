import Foundation

// Auth state manager. Supabase integration wired in Phase 2.
// Currently acts as a stub that stores authenticated state locally.
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false

    private let authenticatedKey = "notyfi.auth.isAuthenticated"

    init() {
        isAuthenticated = UserDefaults.standard.bool(forKey: authenticatedKey)
    }

    // MARK: Sign In

    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }
        // TODO: Supabase Apple Sign In
        await Task.yield()
        setAuthenticated(true)
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        // TODO: Supabase email sign in
        await Task.yield()
        setAuthenticated(true)
    }

    func signUpWithEmail(_ email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        // TODO: Supabase email sign up
        await Task.yield()
        setAuthenticated(true)
    }

    // MARK: Sign Out

    func signOut() {
        // TODO: Supabase sign out
        setAuthenticated(false)
    }

    // MARK: Private

    private func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
        UserDefaults.standard.set(value, forKey: authenticatedKey)
    }
}
