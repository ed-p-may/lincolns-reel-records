import SwiftUI

struct AuthenticationFlowView: View {
    private enum Mode {
        case welcome
        case signIn
        case signUp
        case forgotPassword
    }

    @Environment(AuthService.self) private var authService
    @State private var mode: Mode = .welcome
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var resetRequestSucceeded = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 77 / 255, green: 60 / 255, blue: 34 / 255), ReelTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 72)
                    brand
                    Group {
                        switch mode {
                        case .welcome:
                            welcomeActions
                        case .signIn:
                            authenticationForm(isSignUp: false)
                        case .signUp:
                            authenticationForm(isSignUp: true)
                        case .forgotPassword:
                            forgotPasswordForm
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .authErrorAlert(title: "Unable to continue")
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "fish.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(ReelTheme.accentHighlight)
                .accessibilityHidden(true)
            Text("LINCOLN'S\nREEL RECORDS")
                .reelDisplayFont(48, weight: .black)
                .tracking(-1)
                .foregroundStyle(ReelTheme.primaryText)
                .minimumScaleFactor(0.75)
            Text("Track every catch. Remember every adventure.")
                .font(ReelFont.body(.title3, weight: .medium))
                .foregroundStyle(ReelTheme.secondaryText)
        }
    }

    private var welcomeActions: some View {
        VStack(spacing: 14) {
            PrimaryButton(title: "Create Account", systemImage: "person.badge.plus") {
                mode = .signUp
            }
            Button("Log In") {
                mode = .signIn
            }
            .reelDisplayFont(17)
            .foregroundStyle(ReelTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.strongBorder) }
        }
    }

    private func authenticationForm(isSignUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                mode = .welcome
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .foregroundStyle(ReelTheme.secondaryText)

            Text(isSignUp ? "Create your logbook" : "Welcome back")
                .reelDisplayFont(28, weight: .heavy)

            if isSignUp {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fieldInputStyle()
                    .accessibilityIdentifier("signup.username")
            }

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldInputStyle()
                .accessibilityIdentifier("auth.email")

            SecureField("Password", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .fieldInputStyle()
                .accessibilityIdentifier("auth.password")

            PrimaryButton(
                title: isSignUp ? "Create Account" : "Log In",
                systemImage: "arrow.right",
                isWorking: authService.isWorking
            ) {
                Task { await submit(isSignUp: isSignUp) }
            }
            .disabled(!canSubmit(isSignUp: isSignUp))

            if !isSignUp {
                Button("Forgot password?") {
                    mode = .forgotPassword
                }
                .reelDisplayFont(16)
                .foregroundStyle(ReelTheme.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("auth.forgot-password")
            }

            Text("Password must contain at least 8 characters.")
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
        }
    }

    private var forgotPasswordForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                resetRequestSucceeded = false
                mode = .signIn
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .foregroundStyle(ReelTheme.secondaryText)

            Text("Reset your password")
                .reelDisplayFont(28, weight: .heavy)

            if resetRequestSucceeded {
                Text("Check your email. If an account exists for that address, the reset link will open this app.")
                    .font(ReelFont.body(.body))
                    .foregroundStyle(ReelTheme.secondaryText)
                    .accessibilityIdentifier("auth.reset-sent")
            } else {
                Text("Enter the email address for your logbook.")
                    .font(ReelFont.body(.body))
                    .foregroundStyle(ReelTheme.secondaryText)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .fieldInputStyle()
                    .accessibilityIdentifier("auth.reset-email")

                PrimaryButton(
                    title: "Send Reset Link",
                    systemImage: "envelope",
                    isWorking: authService.isWorking
                ) {
                    Task {
                        resetRequestSucceeded = await authService.requestPasswordReset(email: trimmedEmail)
                    }
                }
                .disabled(trimmedEmail.isEmpty)
                .accessibilityIdentifier("auth.send-reset")
            }
        }
    }

    private func canSubmit(isSignUp: Bool) -> Bool {
        !trimmedEmail.isEmpty && password.count >= 8 && (!isSignUp || !trimmedUsername.isEmpty)
    }

    private func submit(isSignUp: Bool) async {
        if isSignUp {
            await authService.signUp(username: trimmedUsername, email: trimmedEmail, password: password)
        } else {
            await authService.signIn(email: trimmedEmail, password: password)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PasswordRecoveryView: View {
    @Environment(AuthService.self) private var authService
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        ZStack {
            ReelTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer(minLength: 72)
                    Image(systemName: "key.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(ReelTheme.accent)
                        .accessibilityHidden(true)
                    Text("Choose a new password")
                        .reelDisplayFont(32, weight: .heavy)
                    Text("Use at least 8 characters. You will stay signed in after it is updated.")
                        .font(ReelFont.body(.body))
                        .foregroundStyle(ReelTheme.secondaryText)

                    SecureField("New password", text: $password)
                        .textContentType(.newPassword)
                        .fieldInputStyle()
                        .accessibilityIdentifier("auth.new-password")
                    SecureField("Confirm password", text: $confirmation)
                        .textContentType(.newPassword)
                        .fieldInputStyle()
                        .accessibilityIdentifier("auth.confirm-password")

                    PrimaryButton(
                        title: "Update Password",
                        systemImage: "checkmark",
                        isWorking: authService.isWorking
                    ) {
                        Task { await authService.updateRecoveredPassword(password) }
                    }
                    .disabled(password.count < 8 || password != confirmation)
                    .accessibilityIdentifier("auth.update-password")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .authErrorAlert(title: "Unable to update password")
    }
}

private struct AuthErrorAlertModifier: ViewModifier {
    @Environment(AuthService.self) private var authService
    let title: String

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { authService.errorMessage != nil },
                set: {
                    if !$0 {
                        authService.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { authService.clearError() }
        } message: {
            Text(authService.errorMessage ?? "Unknown error")
        }
    }
}

private extension View {
    func authErrorAlert(title: String) -> some View {
        modifier(AuthErrorAlertModifier(title: title))
    }
}
