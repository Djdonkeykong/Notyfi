import SwiftUI
import AuthenticationServices

struct OnboardingSignInView: View {
    @ObservedObject var authManager: AuthManager
    let onBack: () -> Void

    @State private var showEmailSignIn = false
    @State private var showEmailSignUp = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton(action: onBack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingIllustration(symbol: "person.fill", size: 60)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)

                    Text("Welcome back")
                        .font(.notyfi(.title, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Sign in to your account to pick up right where you left off.")
                        .font(.notyfi(.body))
                        .foregroundStyle(NotyfiTheme.secondaryText)
                        .lineSpacing(3)

                    if let error = errorMessage {
                        Text(error)
                            .font(.notyfi(.caption))
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                appleSignInButton
                googleSignInButton
                emailSignInButton

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(NotyfiTheme.secondaryText)
                    Button("Sign up") {
                        showEmailSignUp = true
                    }
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                    .fontWeight(.semibold)
                }
                .font(.notyfi(.subheadline))
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignUpView(authManager: authManager, initialIsSignIn: true)
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView(authManager: authManager, initialIsSignIn: false)
        }
    }

    private var appleSignInButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            signInWithApple()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 21, height: 21)
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
                Image("GoogleGLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 21, height: 21)
                Text("Continue with Google")
                    .font(.notyfi(.body, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .disabled(authManager.isLoading)
    }

    private var emailSignInButton: some View {
        OnboardingPrimaryButton(title: "Continue with Email", isLoading: authManager.isLoading) {
            showEmailSignIn = true
        }
    }

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
                // User dismissed — do nothing
            } catch {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }
}

#Preview {
    OnboardingSignInView(authManager: AuthManager(), onBack: {})
}
