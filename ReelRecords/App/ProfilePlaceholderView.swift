import SwiftUI

struct ProfilePlaceholderView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator

    let account: AccountSession

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(ReelTheme.accentHighlight)
            Text("@\(account.username)")
                .font(ReelFont.display(26, weight: .heavy))
            Text(account.email)
                .font(ReelFont.metadata())
                .foregroundStyle(ReelTheme.secondaryText)
            if account.isOffline {
                Label("Offline session", systemImage: "wifi.slash")
                    .font(ReelFont.metadata())
                    .foregroundStyle(ReelTheme.secondaryText)
            }

            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        let count = try repository.pendingCount(ownerID: account.ownerID)
                        await authService.signOut(pendingCatchCount: count)
                    } catch {
                        authService.blockSignOut(for: error)
                    }
                }
            }
            .font(ReelFont.display(17))
            .foregroundStyle(ReelTheme.danger)
            .disabled(authService.isWorking)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReelTheme.background)
        .navigationTitle("You")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if syncCoordinator.isSyncing {
                    ProgressView()
                        .tint(ReelTheme.accent)
                        .accessibilityLabel("Syncing")
                }
            }
        }
        .alert(
            "Cannot sign out",
            isPresented: Binding(
                get: { authService.signOutFailure != nil },
                set: {
                    if !$0 {
                        authService.clearSignOutFailure()
                    }
                }
            )
        ) {
            if authService.signOutFailure?.canRetrySync == true {
                Button("Retry Sync") {
                    Task { await syncCoordinator.sync(ownerID: account.ownerID) }
                }
            }
            Button("Cancel", role: .cancel) { authService.clearSignOutFailure() }
        } message: {
            Text(authService.signOutFailure?.message ?? "")
        }
    }
}
