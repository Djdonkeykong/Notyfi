import SwiftUI
import AuthenticationServices

struct OnboardingAuthView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var showEmailSignUp = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // No progress bar on final step — auth is the "finish line"
            HStack {
                OnboardingBackButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    illustration
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)

                    Text("Save Your Data")
                        .font(.notyfi(.title, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Create an account to back up your entries, sync across devices, and never lose your data.")
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
                }
                .padding(.horizontal, 24)
            }

            authButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView(authManager: authManager)
        }
    }

    // MARK: - Subviews

    private var illustration: some View {
        OnboardingIllustration(symbol: "person.badge.shield.checkmark.fill", size: 64)
    }

    private var authButtons: some View {
        VStack(spacing: 12) {
            appleSignInButton
            googleSignInButton

            divider

            OnboardingPrimaryButton(
                title: "Use email instead",
                isLoading: false
            ) {
                showEmailSignUp = true
            }
        }
    }

    private var appleSignInButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            signInWithApple()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                Text("Continue with Apple")
                    .font(.notyfi(.body, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.black)
            .clipShape(Capsule())
        }
        .disabled(authManager.isLoading)
    }

    private var googleSignInButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            signInWithGoogle()
        } label: {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Continue with Google")
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .disabled(authManager.isLoading)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
            Text("or")
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
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch let error as AuthError where error.isCancelled {
                // User dismissed — do nothing
            } catch {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }

    private func signInWithApple() {
        errorMessage = nil
        Task {
            do {
                try await authManager.signInWithApple()
            } catch let error as AuthError where error.isCancelled {
                // User dismissed the sheet — do nothing
            } catch {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }
}

// MARK: - Email Sign Up Sheet

struct EmailSignUpView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignIn = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                NotyfiTheme.brandLight.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isSignIn ? "Welcome back" : "Create account")
                            .font(.notyfi(.title2, weight: .bold))
                        Text(isSignIn ? "Sign in to your Notyfi account." : "Start tracking. Your data, always backed up.")
                            .font(.notyfi(.subheadline))
                            .foregroundStyle(NotyfiTheme.secondaryText)
                    }

                    VStack(spacing: 12) {
                        inputField(label: "Email", text: $email, field: .email,
                                   keyboard: .emailAddress, contentType: .emailAddress)
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
                        Text(isSignIn ? "No account?" : "Already have one?")
                            .foregroundStyle(NotyfiTheme.secondaryText)
                        Button(isSignIn ? "Sign up" : "Sign in") {
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
                    Button("Cancel") { dismiss() }
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
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
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
            errorMessage = "Please fill in all fields."
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
                        errorMessage = "Check your inbox and confirm your email, then sign in."
                        isSignIn = true
                    } else {
                        dismiss()
                    }
                }
            } catch let error as AuthError where error.isCancelled {
                // Ignore cancellation silently
            } catch {
                errorMessage = isSignIn
                    ? "Sign in failed. Check your credentials."
                    : "Sign up failed. Please try again."
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingAuthView(authManager: AuthManager())
    }
}
