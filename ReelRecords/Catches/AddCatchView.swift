import SwiftUI

struct AddCatchView: View {
    private static let suggestedSpecies = [
        "Largemouth Bass",
        "Smallmouth Bass",
        "Northern Pike",
        "Walleye",
        "Crappie",
        "Bluegill",
        "Channel Catfish",
        "Rainbow Trout"
    ]

    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(CatchLocationService.self) private var locationService
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var selectedSpecies: String
    @State private var customSpecies: String
    @State private var weight: String
    @State private var length: String
    @State private var caughtAt: Date
    @State private var location: String
    @State private var coordinate: CatchCoordinate?
    @State private var lureText: String
    @State private var rodReel: String
    @State private var notes: String
    @State private var released: Bool
    @State private var photoSessionID = UUID()
    @State private var photos: [EditableCatchPhoto] = []
    @State private var didLoadPhotos = false
    @State private var didCommitPhotos = false
    @State private var didNotifySaved = false
    @State private var persistedCatchID: UUID?
    @State private var isChoosingLocation = false
    @State private var errorMessage: String?

    let ownerID: UUID
    let editItem: CatchItem?
    let onSaved: () -> Void

    init(ownerID: UUID, editItem: CatchItem? = nil, onSaved: @escaping () -> Void) {
        self.ownerID = ownerID
        self.editItem = editItem
        self.onSaved = onSaved

        let values = editItem?.values
        let species = values?.species ?? ""
        _selectedSpecies = State(initialValue: Self.suggestedSpecies.contains(species) ? species : "")
        _customSpecies = State(initialValue: Self.suggestedSpecies.contains(species) ? "" : species)
        _weight = State(initialValue: CatchFormatting.input(values?.weight))
        _length = State(initialValue: CatchFormatting.input(values?.length))
        _caughtAt = State(initialValue: values?.caughtAt ?? .now)
        _location = State(initialValue: values?.location ?? "")
        _coordinate = State(initialValue: values?.coordinate)
        _lureText = State(initialValue: values?.lureText ?? "")
        _rodReel = State(initialValue: values?.rodReel ?? "")
        _notes = State(initialValue: values?.notes ?? "")
        _released = State(initialValue: values?.released ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CatchPhotoEditor(photos: $photos, sessionID: photoSessionID) { message in
                        errorMessage = message
                    }
                    speciesSection
                    measurementSection
                    caughtSection
                    CatchLocationEditor(
                        location: $location,
                        coordinate: $coordinate,
                        isChoosingLocation: $isChoosingLocation
                    )
                    textSection
                    releaseSection

                    Text("Species and caught date/time are required. Everything else can be added later.")
                        .font(ReelFont.body(.footnote))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ReelTheme.background)
            .navigationTitle(editItem == nil ? "Log a Catch" : "Edit Catch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: editItem == nil ? "Save Catch" : "Save Changes",
                    systemImage: "checkmark"
                ) {
                    save()
                }
                .disabled(finalSpecies.isEmpty)
                .padding(20)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("add.save")
            }
        }
        .task {
            locationService.reset()
            loadPhotos()
        }
        .onChange(of: locationService.state) { _, state in
            if case let .captured(capturedCoordinate, _) = state {
                coordinate = capturedCoordinate
            }
        }
        .sheet(isPresented: $isChoosingLocation) {
            ManualLocationPicker(initialCoordinate: coordinate) { selected in
                locationService.reset()
                coordinate = selected
            }
        }
        .onDisappear {
            locationService.reset()
            if !didCommitPhotos {
                try? photoRepository.discardDrafts(sessionID: photoSessionID)
            }
        }
        .alert("Unable to finish save", isPresented: Binding(
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

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Species")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 10) {
                ForEach(Self.suggestedSpecies, id: \.self) { species in
                    speciesButton(species)
                }
            }

            TextField("Other species", text: $customSpecies)
                .textInputAutocapitalization(.words)
                .fieldInputStyle()
                .accessibilityIdentifier("add.species.custom")
                .onChange(of: customSpecies) {
                    if !customSpecies.isEmpty {
                        selectedSpecies = ""
                    }
                }
        }
    }

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Measurements")
            HStack(spacing: 12) {
                measurementInput("Weight", unit: "lb", text: $weight, identifier: "add.weight")
                measurementInput("Length", unit: "in", text: $length, identifier: "add.length")
            }
        }
    }

    private var caughtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Caught")
            DatePicker(
                "Date and time",
                selection: $caughtAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .tint(ReelTheme.accent)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("add.caught-at")
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Details")
            TextField("Lure or bait", text: $lureText)
                .fieldInputStyle()
                .accessibilityIdentifier("add.lure")
            TextField("Rod and reel", text: $rodReel)
                .fieldInputStyle()
                .accessibilityIdentifier("add.rod-reel")
            TextField("Field notes", text: $notes, axis: .vertical)
                .lineLimit(4 ... 8)
                .fieldInputStyle()
                .accessibilityIdentifier("add.notes")
        }
    }

    private var releaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("Disposition")
            Picker("Disposition", selection: $released) {
                Text("Released").tag(true)
                Text("Kept").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("add.released")
        }
    }
}

private extension AddCatchView {
    private var finalSpecies: String {
        let custom = customSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? selectedSpecies : custom
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .tracking(1)
            .foregroundStyle(ReelTheme.tertiaryText)
    }

    private func speciesButton(_ species: String) -> some View {
        SelectionChip(title: species, isSelected: selectedSpecies == species, sizing: .fillWidth) {
            selectedSpecies = species
            customSpecies = ""
        }
        .accessibilityIdentifier("add.species.\(species)")
    }

    private func measurementInput(
        _ title: String,
        unit: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        HStack(spacing: 8) {
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(ReelFont.metadata(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
        .fieldInputStyle()
    }

    private func save() {
        locationService.reset()
        do {
            let values = try CatchValues(
                species: finalSpecies,
                weight: CatchFormatting.parseOptionalMeasurement(weight, field: .weight),
                length: CatchFormatting.parseOptionalMeasurement(length, field: .length),
                caughtAt: caughtAt,
                location: location,
                coordinate: coordinate,
                lureText: lureText,
                rodReel: rodReel,
                notes: notes,
                released: released
            )
            let catchItem: CatchItem
            if let catchID = editItem?.id ?? persistedCatchID {
                catchItem = try repository.update(id: catchID, ownerID: ownerID, values: values)
            } else {
                catchItem = try repository.create(NewCatch(ownerID: ownerID, values: values))
                persistedCatchID = catchItem.id
            }
            do {
                try photoRepository.saveOrder(
                    catchID: catchItem.id,
                    ownerID: ownerID,
                    orderedIDs: photos.map(\.id),
                    drafts: photos.compactMap(\.draft)
                )
                try photoRepository.discardDrafts(sessionID: photoSessionID)
                didCommitPhotos = true
            } catch {
                notifySaved()
                errorMessage = "The catch is saved locally, but its photos were not attached: "
                    + error.localizedDescription
                return
            }
            notifySaved()
            dismiss()
            Task { await syncCoordinator.sync(ownerID: ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPhotos() {
        guard !didLoadPhotos else { return }
        didLoadPhotos = true
        guard let editItem else { return }
        do {
            photos = try photoRepository.photos(catchID: editItem.id, ownerID: ownerID).map { photo in
                EditableCatchPhoto(
                    source: .existing(photo),
                    fileURL: photoRepository.fileURL(for: photo)
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notifySaved() {
        guard !didNotifySaved else { return }
        didNotifySaved = true
        onSaved()
    }

    private func cancel() {
        locationService.reset()
        try? photoRepository.discardDrafts(sessionID: photoSessionID)
        dismiss()
    }
}

private struct CatchLocationEditor: View {
    @Environment(CatchLocationService.self) private var locationService
    @Binding var location: String
    @Binding var coordinate: CatchCoordinate?
    @Binding var isChoosingLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCATION")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(1)
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Named spot", text: $location)
                .textInputAutocapitalization(.words)
                .fieldInputStyle()
                .accessibilityIdentifier("add.location")
            pinEditor
        }
    }

    private var pinEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: coordinate == nil ? "mappin.slash" : "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(coordinate == nil ? ReelTheme.tertiaryText : ReelTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(coordinate == nil ? "No coordinate pin" : "Catch pin saved")
                        .font(ReelFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(ReelTheme.primaryText)
                    Text(statusMessage)
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
                Spacer()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { locationButtons }
                VStack(spacing: 10) { locationButtons }
            }
            if coordinate != nil {
                Button("Clear Pin", role: .destructive) {
                    coordinate = nil
                    locationService.reset()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("add.location.clear")
            }
        }
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
    }

    @ViewBuilder
    private var locationButtons: some View {
        Button {
            locationService.requestCurrentLocation()
        } label: {
            Label("Use Current", systemImage: "location.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(locationService.state == .requestingPermission || locationService.state == .locating)
        .accessibilityIdentifier("add.location.current")

        Button {
            isChoosingLocation = true
        } label: {
            Label("Choose on Map", systemImage: "map.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .accessibilityIdentifier("add.location.manual")
    }

    private var statusMessage: String {
        guard let coordinate else { return locationService.state.message }
        if case let .captured(captured, _) = locationService.state, captured == coordinate {
            return locationService.state.message
        }
        return coordinate.displayLabel
    }
}
