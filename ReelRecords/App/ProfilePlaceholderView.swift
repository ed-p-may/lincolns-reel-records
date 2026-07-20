import SwiftUI

struct ProfilePlaceholderView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SwiftDataTackleRepository.self) private var tackleRepository
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

            NavigationLink {
                TackleBoxView(ownerID: account.ownerID)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(ReelTheme.accentHighlight)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Tackle Box")
                            .font(ReelFont.body(.body, weight: .semibold))
                            .foregroundStyle(ReelTheme.primaryText)
                        Text("Lures, bait, and gear")
                            .font(ReelFont.body(.caption))
                            .foregroundStyle(ReelTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ReelTheme.tertiaryText)
                }
                .padding(15)
                .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.border) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.tackle-box")

            Button("Sign Out", role: .destructive) {
                Task {
                    do {
                        let count = try repository.pendingCount(ownerID: account.ownerID)
                            + photoRepository.pendingCount(ownerID: account.ownerID)
                            + tackleRepository.pendingCount(ownerID: account.ownerID)
                        await authService.signOut(pendingChangeCount: count)
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
                    Task { await syncCoordinator.sync(ownerID: account.ownerID, confirmingConflicts: true) }
                }
            }
            Button("Cancel", role: .cancel) { authService.clearSignOutFailure() }
        } message: {
            Text(authService.signOutFailure?.message ?? "")
        }
    }
}
