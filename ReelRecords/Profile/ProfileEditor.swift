import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataProfileRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var displayName: String
    @State private var homeWater: String
    @State private var anglerSince: String
    @State private var pickerItem: PhotosPickerItem?
    @State private var draftAvatar: DraftPhoto?
    @State private var removeExistingAvatar = false
    @State private var isShowingCamera = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var sessionID = UUID()
    @State private var didSave = false

    let account: AccountSession
    let profile: UserProfile
    let onSaved: (UserProfile) -> Void

    init(account: AccountSession, profile: UserProfile, onSaved: @escaping (UserProfile) -> Void) {
        self.account = account
        self.profile = profile
        self.onSaved = onSaved
        _displayName = State(initialValue: profile.values.displayName ?? "")
        _homeWater = State(initialValue: profile.homeWater ?? "")
        _anglerSince = State(initialValue: profile.anglerSince.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    avatarSection
                    profileFields
                    identitySection
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ReelTheme.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save Profile", systemImage: "checkmark") { save() }
                    .disabled(isImporting)
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .accessibilityIdentifier("profile.editor.save")
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPickerItem(newItem) }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker { data in
                isShowingCamera = false
                if let data {
                    Task { await importData(data) }
                }
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .onDisappear {
            if !didSave {
                try? repository.discardDrafts(sessionID: sessionID)
            }
        }
        .alert("Unable to save profile", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 14) {
            ProfileAvatar(url: displayedAvatarURL, size: 112)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { avatarButtons }
                VStack(spacing: 10) { avatarButtons }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatarButtons: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(isImporting)
        .accessibilityIdentifier("profile.editor.choose-photo")

        Button {
            isShowingCamera = true
        } label: {
            Label("Take Photo", systemImage: "camera.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(!isCameraAvailable || isImporting)

        if draftAvatar != nil || (profile.avatarStoragePath != nil && !removeExistingAvatar) {
            Button("Remove", role: .destructive) {
                draftAvatar = nil
                removeExistingAvatar = true
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("profile.editor.remove-photo")
        }
    }

    private var profileFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            editorField("Display name · optional") {
                TextField(account.username, text: $displayName)
                    .textInputAutocapitalization(.words)
                    .fieldInputStyle()
                    .accessibilityIdentifier("profile.editor.display-name")
            }
            editorField("Home water · optional") {
                TextField("Stockbridge Bowl", text: $homeWater)
                    .textInputAutocapitalization(.words)
                    .fieldInputStyle()
                    .accessibilityIdentifier("profile.editor.home-water")
            }
            editorField("Angler since · optional") {
                TextField("2019", text: $anglerSince)
                    .keyboardType(.numberPad)
                    .fieldInputStyle()
                    .accessibilityIdentifier("profile.editor.angler-since")
            }
        }
    }

    private var identitySection: some View {
        ProfileCard(title: "Account identity") {
            ProfileRow(icon: "at", title: "@\(account.username)", detail: "Username cannot be changed", value: nil)
            Divider().overlay(ReelTheme.border)
            ProfileRow(icon: "envelope", title: account.email, detail: "Email cannot be changed here", value: nil)
        }
    }

    private var displayedAvatarURL: URL? {
        if let draftAvatar {
            return repository.fileURL(for: draftAvatar)
        }
        return removeExistingAvatar ? nil : repository.fileURL(for: profile)
    }

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: {
            if !$0 {
                errorMessage = nil
            }
        })
    }

    private func editorField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ReelTheme.tertiaryText)
            content()
        }
    }
}

private extension ProfileEditor {
    func importPickerItem(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoFileStoreError.invalidImage
            }
            try await stageAvatar(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importData(_ data: Data) async {
        isImporting = true
        defer { isImporting = false }
        do {
            try await stageAvatar(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stageAvatar(_ data: Data) async throws {
        draftAvatar = try await repository.stageAsync(data: data, sessionID: sessionID)
        removeExistingAvatar = false
    }

    func save() {
        do {
            let yearText = anglerSince.trimmingCharacters(in: .whitespacesAndNewlines)
            guard yearText.isEmpty || Int(yearText) != nil else {
                errorMessage = "Angler since must be a four-digit year."
                return
            }
            let avatarChange: ProfileAvatarChange = if let draftAvatar {
                .replace(draftAvatar)
            } else if removeExistingAvatar {
                .remove
            } else {
                .keep
            }
            let saved = try repository.update(
                ownerID: account.ownerID,
                values: ProfileValues(
                    displayName: displayName,
                    homeWater: homeWater,
                    anglerSince: Int(yearText)
                ),
                avatarChange: avatarChange
            )
            didSave = true
            try? repository.discardDrafts(sessionID: sessionID)
            onSaved(saved)
            Task { await syncCoordinator.sync(ownerID: account.ownerID) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
