import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService
    @Environment(SwiftDataCatchRepository.self) private var catchRepository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SwiftDataTackleRepository.self) private var tackleRepository
    @Environment(SwiftDataProfileRepository.self) private var profileRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var profile: UserProfile?
    @State private var catches: [CatchItem] = []
    @State private var isEditing = false
    @State private var isConfirmingDeletion = false
    @State private var errorMessage: String?

    let account: AccountSession

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                profileHeader
                if profile?.syncState == .conflict {
                    conflictBanner
                }
                statsSection
                breakdownSection
                tackleLink
                settingsSection
                accountSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(ReelTheme.background)
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { syncToolbar }
        .task(id: syncCoordinator.revision) { reload() }
        .refreshable {
            await syncCoordinator.sync(ownerID: account.ownerID)
            reload()
        }
        .fullScreenCover(isPresented: $isEditing) {
            if let profile {
                ProfileEditor(account: account, profile: profile) { saved in
                    self.profile = saved
                    isEditing = false
                }
            }
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Account and Data", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently deletes your hosted account, catches, photos, tackle, and local data. "
                    + "It cannot be undone."
            )
        }
        .alert("Profile unavailable", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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

    private var insights: ProfileInsights {
        ProfileDerivation.insights(from: catches)
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ProfileAvatar(url: profile.flatMap(profileRepository.fileURL(for:)), size: 92)
            VStack(spacing: 4) {
                Text(profile?.displayName ?? account.username)
                    .reelDisplayFont(27, weight: .heavy)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("profile.display-name")
                Text("@\(account.username)")
                    .font(ReelFont.metadata(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.accentHighlight)
                if let detailLine {
                    Text(detailLine)
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            Button("Edit Profile") { isEditing = true }
                .buttonStyle(.borderedProminent)
                .tint(ReelTheme.accent)
                .foregroundStyle(ReelTheme.accentInk)
                .accessibilityIdentifier("profile.edit")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(
                colors: [ReelTheme.accent.opacity(0.20), ReelTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(ReelTheme.accent.opacity(0.25)) }
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ProfileStatTile(value: insights.totalCatches.formatted(), label: "Total")
            ProfileStatTile(
                value: insights.personalBest?.weight.map(CatchFormatting.weight) ?? "—",
                label: "Personal best"
            )
            ProfileStatTile(value: insights.speciesCount.formatted(), label: "Species")
        }
        .accessibilityIdentifier("profile.stats")
    }

    private var breakdownSection: some View {
        ProfileCard(title: "Species breakdown") {
            if let signature = insights.signatureSpecies {
                Label("Signature species · \(signature.label)", systemImage: "star.fill")
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.accentHighlight)
                ForEach(Array(insights.speciesBreakdown.enumerated()), id: \.offset) { _, stat in
                    ProfileSpeciesBar(stat: stat, maximum: signature.count)
                }
            } else {
                ContentUnavailableView(
                    "No catches yet",
                    systemImage: "fish",
                    description: Text("Your species breakdown will grow with your logbook.")
                )
            }
        }
        .accessibilityIdentifier("profile.species-breakdown")
    }

    private var tackleLink: some View {
        NavigationLink {
            TackleBoxView(ownerID: account.ownerID)
        } label: {
            ProfileRow(
                icon: "shippingbox.fill",
                title: "My Tackle Box",
                detail: "Lures, bait, and gear",
                value: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.tackle-box")
    }

    private var settingsSection: some View {
        ProfileCard(title: "Settings") {
            ProfileRow(icon: "ruler", title: "Units", detail: "Imperial in v1", value: "lb · in")
            Divider().overlay(ReelTheme.border)
            ProfileRow(icon: "bell.slash", title: "Notifications", detail: "Coming Soon", value: nil)
                .opacity(0.62)
            Divider().overlay(ReelTheme.border)
            ProfileRow(icon: "square.and.arrow.up", title: "Export Logbook", detail: "Coming Soon", value: nil)
                .opacity(0.62)
        }
    }

    private var accountSection: some View {
        ProfileCard(title: "Account") {
            ProfileRow(icon: "envelope", title: account.email, detail: "Signed in as @\(account.username)", value: nil)
            Divider().overlay(ReelTheme.border)
            Button(role: .destructive) { signOut() } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(authService.isWorking || authService.hasPendingLocalAccountDeletion)
            Divider().overlay(ReelTheme.border)
            Button(role: .destructive) { isConfirmingDeletion = true } label: {
                Label("Delete Account", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(account.isOffline || authService.isWorking)
            if account.isOffline {
                Text("Connect to the internet to delete your account.")
                    .font(ReelFont.body(.caption2))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
        }
    }

    private var conflictBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Profile changed on another device", systemImage: "exclamationmark.triangle.fill")
                .font(ReelFont.body(.subheadline, weight: .bold))
            Text("Keep this device’s profile by confirming the next sync.")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
            Button("Keep Mine and Sync") {
                Task { await syncCoordinator.sync(ownerID: account.ownerID, confirmingConflicts: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(ReelTheme.accent)
        }
        .padding(16)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ToolbarContentBuilder
    private var syncToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if syncCoordinator.isSyncing {
                ProgressView().tint(ReelTheme.accent).accessibilityLabel("Syncing")
            }
        }
    }

    private var detailLine: String? {
        let since = profile?.anglerSince.map { "Angler since \($0)" }
        let water = profile?.homeWater
        let components = [since, water].compactMap(\.self)
        return components.isEmpty ? nil : components.joined(separator: " · ")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: {
            if !$0 {
                errorMessage = nil
            }
        })
    }

    private func reload() {
        do {
            profile = try profileRepository.profile(account: account)
            catches = try catchRepository.list(ownerID: account.ownerID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() {
        Task {
            do {
                let count = try catchRepository.pendingCount(ownerID: account.ownerID)
                    + photoRepository.pendingCount(ownerID: account.ownerID)
                    + tackleRepository.pendingCount(ownerID: account.ownerID)
                    + profileRepository.pendingCount(ownerID: account.ownerID)
                await authService.signOut(pendingChangeCount: count)
            } catch {
                authService.blockSignOut(for: error)
            }
        }
    }

    private func deleteAccount() {
        Task {
            await syncCoordinator.suspendAndWait(ownerID: account.ownerID)
            let deleted = await authService.deleteAccount {
                try profileRepository.purgeLocalAccountData(ownerID: account.ownerID)
            }
            if !deleted {
                errorMessage = authService.errorMessage ?? "Account deletion failed."
                if !authService.hasPendingLocalAccountDeletion {
                    syncCoordinator.resume(ownerID: account.ownerID)
                }
            }
        }
    }
}
