import SwiftUI
import AuthenticationServices

struct OnboardingSignInView: View {
    @ObservedObject var authManager: AuthManager
    var onBack: (() -> Void)? = nil
    var onSignUp: (() -> Void)? = nil

    @State private var showEmailSignIn = false
    @State private var errorMessage: String? = nil
    @State private var loadingProvider: AuthProvider? = nil

    private enum AuthProvider { case apple, google, email }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Spacer()

                SketchAnimatedImage(
                    frames: ["mascot-welcome-f1","mascot-welcome-f2","mascot-welcome-f3","mascot-welcome-f4"],
                    fps: 6
                )
                .frame(width: 346, height: 346)
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 36)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Welcome back".notyfiLocalized)
                        .font(.notyfi(.title2, weight: .bold))
                        .padding(.bottom, 10)

                    Text("Sign in to your account to pick up right where you left off.".notyfiLocalized)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    appleSignInButton
                    googleSignInButton
                    emailSignInButton

                    HStack(spacing: 4) {
                        Text("Don't have an account?".notyfiLocalized)
                            .foregroundStyle(NotyfiTheme.secondaryText)
                        Button("Sign up".notyfiLocalized) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSignUp?()
                        }
                        .foregroundStyle(NotyfiTheme.brandPrimary)
                        .fontWeight(.semibold)
                    }
                    .font(.notyfi(.subheadline))
                    .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let onBack {
                HStack {
                    OnboardingBackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignUpView(authManager: authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
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

    private var emailSignInButton: some View {
        OnboardingPrimaryButton(title: "Continue with Email", isLoading: loadingProvider == .email) {
            showEmailSignIn = true
        }
    }

    private func signInWithGoogle() {
        errorMessage = nil
        loadingProvider = .google
        Task {
            do {
                try await authManager.signInWithGoogle()
                loadingProvider = nil
            } catch let error as AuthError where error.isCancelled {
                loadingProvider = nil
            } catch {
                loadingProvider = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithApple() {
        errorMessage = nil
        loadingProvider = .apple
        Task {
            do {
                try await authManager.signInWithApple()
                loadingProvider = nil
            } catch let error as AuthError where error.isCancelled {
                loadingProvider = nil
            } catch {
                loadingProvider = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    OnboardingSignInView(authManager: AuthManager(), onBack: {})
}
