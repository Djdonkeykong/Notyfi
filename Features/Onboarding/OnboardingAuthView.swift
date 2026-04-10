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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
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
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    init(authManager: AuthManager, initialIsSignIn: Bool = false) {
        self.authManager = authManager
        self._isSignIn = State(initialValue: initialIsSignIn)
    }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 28)

                VStack(spacing: 14) {
                    emailField
                    passwordField

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
                    .padding(.top, 4)

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
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(authManager: authManager)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top) {
            Text(isSignIn ? "Sign in".notyfiLocalized : "Create account".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(NotyfiTheme.elevatedSurface)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email".notyfiLocalized)
                .font(.notyfi(.caption, weight: .medium))
                .foregroundStyle(NotyfiTheme.secondaryText)
            TextField("", text: $email)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .onChange(of: email) { _, newValue in
                    if newValue.count > 254 { email = String(newValue.prefix(254)) }
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            focusedField == .email ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                            lineWidth: focusedField == .email ? 1.5 : 1
                        )
                }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Password".notyfiLocalized)
                    .font(.notyfi(.caption, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Spacer()
                if isSignIn {
                    Button("Forgot?".notyfiLocalized) {
                        showForgotPassword = true
                    }
                    .font(.notyfi(.caption, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                }
            }
            SecureField("", text: $password)
                .textContentType(isSignIn ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            focusedField == .password ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                            lineWidth: focusedField == .password ? 1.5 : 1
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

// MARK: - Forgot Password Sheet

private struct ForgotPasswordSheet: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSent = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 28)

                if isSent {
                    sentConfirmation
                } else {
                    form
                }

                Spacer()
            }
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top) {
            Text("Reset password".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle()
                            .fill(NotyfiTheme.elevatedSurface)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter your email and we'll send you a reset link.".notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Email".notyfiLocalized)
                    .font(.notyfi(.caption, weight: .medium))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                TextField("", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .focused($emailFocused)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                emailFocused ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                                lineWidth: emailFocused ? 1.5 : 1
                            )
                    }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.notyfi(.caption))
                    .foregroundStyle(.red)
            }

            OnboardingPrimaryButton(title: "Send Reset Link", isLoading: isLoading) {
                sendReset()
            }
        }
        .padding(.horizontal, 20)
    }

    private var sentConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.checkmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(NotyfiTheme.brandPrimary)
                .padding(.bottom, 4)

            Text("Check your inbox".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))

            Text("We sent a reset link to \(email). Follow it to set a new password.".notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func sendReset() {
        errorMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email.".notyfiLocalized
            return
        }
        isLoading = true
        Task {
            do {
                try await authManager.resetPassword(email: trimmed)
                isSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}


#Preview {
    OnboardingAuthView(authManager: AuthManager())
}
