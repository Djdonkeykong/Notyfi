import SwiftUI
import AuthenticationServices

struct OnboardingAuthView: View {
    @ObservedObject var authManager: AuthManager

    @State private var showEmailSignUp = false
    @State private var errorMessage: String? = nil
    @State private var loadingProvider: AuthProvider? = nil

    private enum AuthProvider { case apple, google, email }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                illustration
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                Text("Save your progress".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Create an account to sync your data across devices and never lose your progress.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 8)

                if let error = errorMessage {
                    Text(error)
                        .font(.notyfi(.caption))
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }

                authButtons
                    .padding(.top, 32)
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 16, for: .scrollContent)
        .contentMargins(.bottom, 80, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView(authManager: authManager)
        }
    }

    // MARK: - Subviews

    private var illustration: some View {
        Image("mascot-save")
            .resizable()
            .scaledToFit()
            .frame(width: 288, height: 288)
    }

    private var authButtons: some View {
        VStack(spacing: 12) {
            appleSignInButton
            googleSignInButton

            divider

            OnboardingPrimaryButton(
                title: "Use email instead",
                isLoading: loadingProvider == .email
            ) {
                showEmailSignUp = true
            }
            .disabled(isAnyLoading)
        }
    }

    private var isAnyLoading: Bool { loadingProvider != nil }

    private var appleSignInButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            signInWithApple()
        } label: {
            ZStack {
                if loadingProvider == .apple {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                        Text("Continue with Apple".notyfiLocalized)
                            .font(.notyfi(.body, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.black)
            .clipShape(Capsule())
        }
        .disabled(isAnyLoading)
    }

    private var googleSignInButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            signInWithGoogle()
        } label: {
            ZStack {
                if loadingProvider == .google {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.black)
                } else {
                    HStack(spacing: 10) {
                        Image("GoogleGLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                        Text("Continue with Google".notyfiLocalized)
                            .font(.notyfi(.body, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .disabled(isAnyLoading)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
            Text("or".notyfiLocalized)
                .font(.notyfi(.caption))
                .foregroundStyle(NotyfiTheme.secondaryText)
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        errorMessage = nil
        loadingProvider = .google
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch let error as AuthError where error.isCancelled {
                // User dismissed — do nothing
            } catch {
                errorMessage = error.localizedDescription
            }
            loadingProvider = nil
        }
    }

    private func signInWithApple() {
        errorMessage = nil
        loadingProvider = .apple
        Task {
            do {
                try await authManager.signInWithApple()
            } catch let error as AuthError where error.isCancelled {
                // User dismissed — do nothing
            } catch {
                errorMessage = error.localizedDescription
            }
            loadingProvider = nil
        }
    }
}

// MARK: - Email Sign Up Sheet

struct EmailSignUpView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignIn: Bool
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    init(authManager: AuthManager, initialIsSignIn: Bool = false) {
        self.authManager = authManager
        self._isSignIn = State(initialValue: initialIsSignIn)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NotyfiTheme.brandLight.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isSignIn ? "Welcome back".notyfiLocalized : "Create account".notyfiLocalized)
                            .font(.notyfi(.title2, weight: .bold))
                        Text(isSignIn ? "Sign in to your Notyfi account.".notyfiLocalized : "Start tracking. Your data, always backed up.".notyfiLocalized)
                            .font(.notyfi(.subheadline))
                            .foregroundStyle(NotyfiTheme.secondaryText)
                    }

                    VStack(spacing: 12) {
                        inputField(label: "Email", text: $email, field: .email,
                                   keyboard: .emailAddress, contentType: .emailAddress, maxLength: 254)
                        inputField(label: "Password", text: $password, field: .password,
                                   isSecure: true, contentType: isSignIn ? .password : .newPassword)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.notyfi(.caption))
                            .foregroundStyle(.red)
                    }

                    OnboardingPrimaryButton(
                        title: isSignIn ? "Sign In" : "Create Account",
                        isLoading: authManager.isLoading
                    ) {
                        submit()
                    }

                    HStack(spacing: 4) {
                        Text(isSignIn ? "No account?".notyfiLocalized : "Already have one?".notyfiLocalized)
                            .foregroundStyle(NotyfiTheme.secondaryText)
                        Button(isSignIn ? "Sign up".notyfiLocalized : "Sign in".notyfiLocalized) {
                            isSignIn.toggle()
                            errorMessage = nil
                        }
                        .foregroundStyle(NotyfiTheme.brandPrimary)
                    }
                    .font(.notyfi(.subheadline))

                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".notyfiLocalized) { dismiss() }
                        .foregroundStyle(NotyfiTheme.brandPrimary)
                }
            }
        }
    }

    private func inputField(
        label: String,
        text: Binding<String>,
        field: Field,
        isSecure: Bool = false,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType,
        maxLength: Int? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.notyfiLocalized)
                .font(.notyfi(.caption, weight: .medium))
                .foregroundStyle(NotyfiTheme.secondaryText)
            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .onChange(of: text.wrappedValue) { _, newValue in
                if let max = maxLength, newValue.count > max {
                    text.wrappedValue = String(newValue.prefix(max))
                }
            }
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        focusedField == field ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
        }
    }

    private func submit() {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields.".notyfiLocalized
            return
        }
        Task {
            do {
                if isSignIn {
                    try await authManager.signInWithEmail(email, password: password)
                    dismiss()
                } else {
                    try await authManager.signUpWithEmail(email, password: password)
                    if authManager.pendingEmailConfirmation {
                        // Show confirmation prompt — do not dismiss yet.
                        errorMessage = "Check your inbox and confirm your email, then sign in.".notyfiLocalized
                        isSignIn = true
                    } else {
                        dismiss()
                    }
                }
            } catch let error as AuthError where error.isCancelled {
                // Ignore cancellation silently
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}


#Preview {
    OnboardingAuthView(authManager: AuthManager())
}
