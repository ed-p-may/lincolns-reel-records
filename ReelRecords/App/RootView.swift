import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            switch authService.state {
            case .loading:
                ZStack {
                    ReelTheme.background.ignoresSafeArea()
                    ProgressView("Opening logbook…")
                        .tint(ReelTheme.accent)
                }
            case .signedOut:
                AuthenticationFlowView()
            case let .authenticated(account):
                AppShellView(account: account)
            }
        }
        .task {
            await authService.restoreSession()
        }
    }
}
