import SwiftUI

struct AuthenticationFlowView: View {
    private enum Mode {
        case welcome
        case signIn
        case signUp
    }

    @Environment(AuthService.self) private var authService
    @State private var mode: Mode = .welcome
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""

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
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert(
            "Unable to continue",
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

    private var brand: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "fish.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(ReelTheme.accentHighlight)
                .accessibilityHidden(true)
            Text("LINCOLN'S\nREEL RECORDS")
                .font(ReelFont.display(48, weight: .black))
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
            .font(ReelFont.display(17))
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
                .font(ReelFont.display(28, weight: .heavy))

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

            Text("Password must contain at least 8 characters.")
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
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
