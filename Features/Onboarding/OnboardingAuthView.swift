import SwiftUI
import AuthenticationServices

struct OnboardingAuthView: View {
    @ObservedObject var authManager: AuthManager
    var onBack: (() -> Void)? = nil

    @State private var showEmailSignUp = false
    @State private var errorMessage: String? = nil
    @State private var loadingProvider: AuthProvider? = nil

    private enum AuthProvider { case apple, google, email }

    var body: some View {
        ZStack(alignment: .topLeading) {
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
            .toolbar(.hidden, for: .navigationBar)

            LinearGradient(
                stops: [
                    .init(color: NotyfiTheme.brandLight, location: 0),
                    .init(color: NotyfiTheme.brandLight, location: 0.30),
                    .init(color: NotyfiTheme.brandLight.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

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
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView(authManager: authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(26)
        }
    }

    // MARK: - Subviews

    private var illustration: some View {
        SketchAnimatedImage(
            frames: ["mascot-auth-f1","mascot-auth-f2","mascot-auth-f3","mascot-auth-f4"],
            fps: 6
        )
        .frame(height: 260)
        .frame(maxWidth: .infinity)
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

// MARK: - Email OTP Sheet

struct EmailSignUpView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var otpCode = ""
    @State private var step: Step = .email
    @State private var errorMessage: String? = nil
    @State private var resendCooldown: Int = 0
    @State private var isSending = false
    @State private var isVerifying = false
    @State private var cursorVisible = true
    @FocusState private var emailFocused: Bool
    @FocusState private var otpFocused: Bool

    // When true, OTP is sent with shouldCreateUser: false — blocks new-account creation
    // and shows a user-friendly error if the email isn't registered.
    private let isSignIn: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Step { case email, otp }

    init(authManager: AuthManager, initialIsSignIn: Bool = false) {
        self.authManager = authManager
        self.isSignIn = initialIsSignIn
    }

    var body: some View {
        ZStack {
            NotyfiTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 28)

                if step == .email {
                    emailStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    otpStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }

                Spacer()
            }
        }
        .onReceive(timer) { _ in
            if resendCooldown > 0 { resendCooldown -= 1 }
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top) {
            Text(step == .email ? "Continue with email".notyfiLocalized : "Check your inbox".notyfiLocalized)
                .font(.notyfi(.title3, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
                .animation(.none, value: step)

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

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We'll send a 6-digit code to sign you in or create your account.".notyfiLocalized)
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
                    .submitLabel(.go)
                    .onSubmit { sendCode() }
                    .onChange(of: email) { _, v in
                        if v.count > 254 { email = String(v.prefix(254)) }
                    }
                    .padding(16)
                    .background(NotyfiTheme.elevatedSurface)
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

            OnboardingPrimaryButton(title: "Send code".notyfiLocalized, isLoading: isSending) {
                sendCode()
            }
        }
        .padding(.horizontal, 20)
        .onAppear { emailFocused = true }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter the 6-digit code we sent to \(email).".notyfiLocalized)
                .font(.notyfi(.body))
                .foregroundStyle(NotyfiTheme.secondaryText)
                .lineSpacing(3)

            otpBoxes

            if let error = errorMessage {
                Text(error)
                    .font(.notyfi(.caption))
                    .foregroundStyle(.red)
            }

            OnboardingPrimaryButton(title: "Verify".notyfiLocalized, isLoading: isVerifying) {
                verify()
            }
            .disabled(otpCode.count < 6)

            HStack(spacing: 4) {
                Text("Didn't get it?".notyfiLocalized)
                    .foregroundStyle(NotyfiTheme.secondaryText)
                Button(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend".notyfiLocalized) {
                    guard resendCooldown == 0 else { return }
                    sendCode(isResend: true)
                }
                .foregroundStyle(resendCooldown > 0 ? NotyfiTheme.secondaryText : NotyfiTheme.brandPrimary)
                .fontWeight(.semibold)
                .disabled(resendCooldown > 0)
            }
            .font(.notyfi(.subheadline))
            .padding(.top, 8)

            Button {
                withAnimation(.easeInOut(duration: 0.28)) { step = .email }
                otpCode = ""
                errorMessage = nil
            } label: {
                Text("Change email".notyfiLocalized)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .onAppear { otpFocused = true }
    }

    private var otpBoxes: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    let char: String = index < otpCode.count
                        ? String(otpCode[otpCode.index(otpCode.startIndex, offsetBy: index)])
                        : ""
                    let isActive = index == otpCode.count

                    Text(char)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(NotyfiTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isActive ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                                    lineWidth: isActive ? 1.5 : 1
                                )
                        }
                        .overlay {
                            if isActive && otpFocused {
                                Rectangle()
                                    .fill(NotyfiTheme.brandPrimary)
                                    .frame(width: 2, height: 24)
                                    .opacity(cursorVisible ? 1 : 0)
                            }
                        }
                }
            }

            // Transparent overlay on top — receives taps (focusing keyboard) and autofill.
            // Must be last in ZStack (top layer) with hit testing enabled for iOS
            // QuickType autofill to reach it.
            TextField("", text: $otpCode)
                .task(id: otpFocused) {
                    guard otpFocused else { return }
                    cursorVisible = true
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 530_000_000)
                        withAnimation(.easeInOut(duration: 0.12)) { cursorVisible.toggle() }
                    }
                }
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($otpFocused)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.011)
                .onChange(of: otpCode) { _, v in
                    let filtered = v.filter { $0.isNumber }
                    if filtered.count > 6 {
                        otpCode = String(filtered.prefix(6))
                    } else if filtered != v {
                        otpCode = filtered
                    }
                    if otpCode.count == 6 { verify() }
                }
        }
    }

    private func sendCode(isResend: Bool = false) {
        errorMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email.".notyfiLocalized
            return
        }
        isSending = true
        Task {
            do {
                try await authManager.sendOTP(email: trimmed, shouldCreateUser: !isSignIn)
                isSending = false
                otpCode = ""
                resendCooldown = 60
                withAnimation(.easeInOut(duration: 0.28)) { step = .otp }
            } catch {
                isSending = false
                if isSignIn {
                    // Rate-limit and other transient errors have distinct wording —
                    // show the real message so the user knows to wait, not that
                    // their account doesn't exist.
                    let msg = error.localizedDescription.lowercased()
                    let isRateLimit = msg.contains("after") || msg.contains("seconds")
                        || msg.contains("rate") || msg.contains("too many")
                        || msg.contains("security purposes")
                    errorMessage = isRateLimit
                        ? error.localizedDescription
                        : "No account found with this email. Tap \"Sign up\" to create one.".notyfiLocalized
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func verify() {
        errorMessage = nil
        guard otpCode.count == 6 else { return }
        isVerifying = true
        Task {
            do {
                try await authManager.verifyOTP(email: email, token: otpCode)
                isVerifying = false
                dismiss()
            } catch {
                isVerifying = false
                errorMessage = error.localizedDescription
                // Keep otpCode so the user can see what was entered and retry
            }
        }
    }
}


#Preview {
    OnboardingAuthView(authManager: AuthManager())
}
