import PhotosUI
import SwiftUI
import UIKit

struct TackleItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataTackleRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var name: String
    @State private var type: TackleItemType
    @State private var size: String
    @State private var color: String
    @State private var brand: String
    @State private var archived: Bool
    @State private var pickerItem: PhotosPickerItem?
    @State private var draftPhoto: DraftPhoto?
    @State private var removeExistingPhoto = false
    @State private var isShowingCamera = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var sessionID = UUID()
    @State private var didSave = false

    let ownerID: UUID
    let editItem: TackleItem?
    let onSaved: (TackleItem) -> Void

    init(ownerID: UUID, editItem: TackleItem? = nil, onSaved: @escaping (TackleItem) -> Void) {
        self.ownerID = ownerID
        self.editItem = editItem
        self.onSaved = onSaved
        _name = State(initialValue: editItem?.name ?? "")
        _type = State(initialValue: editItem?.type ?? .softPlastic)
        _size = State(initialValue: editItem?.size ?? "")
        _color = State(initialValue: editItem?.color ?? "")
        _brand = State(initialValue: editItem?.brand ?? "")
        _archived = State(initialValue: editItem?.archived ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photoSection
                    field("Name") {
                        TextField("Green Pumpkin Senko", text: $name)
                            .textInputAutocapitalization(.words)
                            .fieldInputStyle()
                            .accessibilityIdentifier("tackle.editor.name")
                    }
                    typeSection
                    HStack(alignment: .top, spacing: 12) {
                        field("Size") {
                            TextField("5\" or 1/2 oz", text: $size)
                                .fieldInputStyle()
                                .accessibilityIdentifier("tackle.editor.size")
                        }
                        field("Brand · optional") {
                            TextField("Yamamoto", text: $brand)
                                .fieldInputStyle()
                                .accessibilityIdentifier("tackle.editor.brand")
                        }
                    }
                    field("Color") {
                        HStack(spacing: 11) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(TackleColor.swatch(color.isEmpty ? nil : color))
                                .frame(width: 52, height: 52)
                                .overlay { RoundedRectangle(cornerRadius: 12).stroke(ReelTheme.border) }
                            TextField("Green Pumpkin", text: $color)
                                .fieldInputStyle()
                                .accessibilityIdentifier("tackle.editor.color")
                        }
                    }
                    if editItem != nil {
                        Toggle(isOn: $archived) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Archived")
                                    .font(ReelFont.body(.body, weight: .semibold))
                                Text("Hide from new Catch pickers; keep historical links.")
                                    .font(ReelFont.body(.caption))
                                    .foregroundStyle(ReelTheme.secondaryText)
                            }
                        }
                        .tint(ReelTheme.accent)
                        .padding(14)
                        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("tackle.editor.archived")
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ReelTheme.background)
            .navigationTitle(editItem == nil ? "Add to Tackle Box" : "Edit Tackle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: editItem == nil ? "Save to Tackle Box" : "Save Changes",
                    systemImage: "checkmark"
                ) { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .accessibilityIdentifier("tackle.editor.save")
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
        .alert("Unable to save tackle", isPresented: Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("PHOTO · OPTIONAL")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ReelTheme.tertiaryText)
            photoPreview
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { photoButtons }
                VStack(spacing: 10) { photoButtons }
            }
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let draftPhoto {
            LocalPhotoImage(
                url: repository.fileURL(for: draftPhoto),
                maximumPixelSize: 700,
                contentMode: .fill,
                placeholder: TacklePhotoPlaceholder(type: type)
            )
        } else if let editItem, !removeExistingPhoto {
            LocalPhotoImage(
                url: repository.fileURL(for: editItem),
                maximumPixelSize: 700,
                contentMode: .fill,
                placeholder: TacklePhotoPlaceholder(type: type)
            )
        } else {
            TacklePhotoPlaceholder(type: type)
                .overlay {
                    Label("Add a photo of this item", systemImage: "camera.fill")
                        .font(ReelFont.body(.subheadline, weight: .semibold))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
        }
    }

    @ViewBuilder
    private var photoButtons: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo")
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(isImporting)
        .accessibilityIdentifier("tackle.editor.choose-photo")

        Button {
            isShowingCamera = true
        } label: {
            Label("Take Photo", systemImage: "camera.fill")
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(!isCameraAvailable || isImporting)
        .accessibilityIdentifier("tackle.editor.take-photo")

        if draftPhoto != nil || (editItem?.photoStoragePath != nil && !removeExistingPhoto) {
            Button("Remove", role: .destructive) {
                draftPhoto = nil
                removeExistingPhoto = true
            }
            .frame(minHeight: 46)
            .accessibilityIdentifier("tackle.editor.remove-photo")
        }
    }

    private var typeSection: some View {
        field("Type") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118))], spacing: 9) {
                ForEach(TackleItemType.allCases) { choice in
                    SelectionChip(
                        title: choice.label,
                        isSelected: type == choice,
                        sizing: .compact
                    ) { type = choice }
                        .accessibilityIdentifier("tackle.editor.type.\(choice.rawValue)")
                }
            }
        }
    }
}

private extension TackleItemEditor {
    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ReelTheme.tertiaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    private func importPickerItem(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoFileStoreError.invalidImage
            }
            await importData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importData(_ data: Data) async {
        do {
            draftPhoto = try await repository.stageAsync(data: data, sessionID: sessionID)
            removeExistingPhoto = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            let values = TackleValues(
                name: name,
                type: type,
                size: size,
                color: color,
                brand: brand,
                archived: archived
            )
            let saved: TackleItem
            if let editItem {
                let change: TacklePhotoChange = if let draftPhoto {
                    .replace(draftPhoto)
                } else if removeExistingPhoto, editItem.photoStoragePath != nil {
                    .remove
                } else {
                    .keep
                }
                saved = try repository.update(
                    id: editItem.id,
                    ownerID: ownerID,
                    values: values,
                    photoChange: change
                )
            } else {
                saved = try repository.create(
                    NewTackleItem(ownerID: ownerID, values: values),
                    photo: draftPhoto
                )
            }
            didSave = true
            try? repository.discardDrafts(sessionID: sessionID)
            onSaved(saved)
            dismiss()
            Task { await syncCoordinator.sync(ownerID: ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
