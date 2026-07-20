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
    @Environment(SwiftDataTackleRepository.self) private var tackleRepository
    @Environment(CatchLocationService.self) private var locationService
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(\.weatherSuggestionProvider) private var weatherSuggestionProvider
    @State private var selectedSpecies: String
    @State private var customSpecies: String
    @State private var weight: String
    @State private var length: String
    @State private var caughtAt: Date
    @State private var location: String
    @State private var coordinate: CatchCoordinate?
    @State private var airTemperature: String
    @State private var skyCondition: SkyCondition?
    @State private var waterTemperature: String
    @State private var waterClarity: WaterClarity?
    @State private var conditionDraft: ConditionEnrichmentDraft
    @State private var completedWeatherKeys: [WeatherRequestKey] = []
    @State private var fetchingWeatherKey: WeatherRequestKey?
    @State private var weatherSuggestionMessage: String?
    @State private var tackleItems: [TackleItem] = []
    @State private var selectedTackleItemID: UUID?
    @State private var isAddingTackle = false
    @State private var isManagingTackle = false
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
        let conditions = values?.conditions ?? .empty
        _airTemperature = State(initialValue: CatchFormatting.input(conditions.airTemperatureF))
        _skyCondition = State(initialValue: conditions.skyCondition)
        _waterTemperature = State(initialValue: CatchFormatting.input(conditions.waterTemperatureF))
        _waterClarity = State(initialValue: conditions.waterClarity)
        _conditionDraft = State(initialValue: ConditionEnrichmentDraft(conditions: conditions))
        _selectedTackleItemID = State(initialValue: values?.tackleItemID)
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
                    conditionsSection
                    CatchTackleSection(
                        items: tackleItems,
                        selectedItemID: $selectedTackleItemID,
                        lureText: $lureText,
                        onAdd: { isAddingTackle = true },
                        onManage: { isManagingTackle = true }
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
            loadTackleItems()
        }
        .task(id: weatherRequestKey) {
            await suggestWeatherIfNeeded()
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
        .sheet(isPresented: $isAddingTackle) {
            TackleItemEditor(ownerID: ownerID) { item in
                loadTackleItems()
                selectedTackleItemID = item.id
            }
        }
        .fullScreenCover(isPresented: $isManagingTackle) {
            NavigationStack {
                TackleBoxView(ownerID: ownerID)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                loadTackleItems()
                                isManagingTackle = false
                            }
                        }
                    }
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
            TextField("Rod and reel", text: $rodReel)
                .fieldInputStyle()
                .accessibilityIdentifier("add.rod-reel")
            TextField("Field notes", text: $notes, axis: .vertical)
                .lineLimit(4 ... 8)
                .fieldInputStyle()
                .accessibilityIdentifier("add.notes")
        }
    }

    private var conditionsSection: some View {
        CatchConditionsEditor(
            airTemperature: $airTemperature,
            skyCondition: $skyCondition,
            waterTemperature: $waterTemperature,
            waterClarity: $waterClarity,
            airIsSuggested: conditionDraft.airSource == .suggested,
            skyIsSuggested: conditionDraft.skySource == .suggested,
            isFetching: fetchingWeatherKey != nil,
            message: weatherSuggestionMessage,
            onAirEdited: { conditionDraft.markAirTemperatureManual() },
            onSkyEdited: { conditionDraft.markSkyConditionManual() }
        )
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

    private var weatherRequestKey: WeatherRequestKey? {
        coordinate.map { WeatherRequestKey(coordinate: $0, caughtAt: caughtAt) }
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
        UnitInput(
            title,
            unit: unit,
            text: text,
            keyboardType: .decimalPad,
            identifier: identifier
        )
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
                conditions: CatchConditions(
                    airTemperatureF: CatchFormatting.parseOptionalTemperature(airTemperature),
                    skyCondition: skyCondition,
                    waterTemperatureF: CatchFormatting.parseOptionalTemperature(waterTemperature),
                    waterClarity: waterClarity
                ),
                tackleItemID: selectedTackleItemID,
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

    private func loadTackleItems() {
        do {
            var loaded = try tackleRepository.items(ownerID: ownerID)
            let historical = try selectedTackleItemID.flatMap {
                try tackleRepository.item(id: $0, ownerID: ownerID)
            }
            if let historical, !loaded.contains(where: { $0.id == historical.id }) {
                loaded.append(historical)
            }
            tackleItems = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func suggestWeatherIfNeeded() async {
        guard let coordinate, let key = weatherRequestKey,
              conditionDraft.airSource == nil || conditionDraft.skySource == nil,
              !completedWeatherKeys.contains(key)
        else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))
            try Task.checkCancellation()
            fetchingWeatherKey = key
            weatherSuggestionMessage = nil
            defer {
                if fetchingWeatherKey == key {
                    fetchingWeatherKey = nil
                }
            }
            let suggestion = try await weatherSuggestionProvider.suggestion(
                at: coordinate,
                caughtAt: caughtAt
            )
            markWeatherRequestCompleted(key)
            guard let suggestion, weatherRequestKey == key else {
                return
            }

            let applied = conditionDraft.apply(suggestion)
            if let airTemperatureF = applied.airTemperatureF {
                airTemperature = CatchFormatting.input(airTemperatureF)
            }
            if let suggestedSky = applied.skyCondition {
                skyCondition = suggestedSky
            }
        } catch is CancellationError {
            return
        } catch {
            if weatherRequestKey == key {
                weatherSuggestionMessage = "Weather suggestion unavailable. Enter conditions manually."
            }
        }
    }

    private func markWeatherRequestCompleted(_ key: WeatherRequestKey) {
        completedWeatherKeys.removeAll { $0 == key }
        completedWeatherKeys.append(key)
        if completedWeatherKeys.count > 8 {
            completedWeatherKeys.removeFirst(completedWeatherKeys.count - 8)
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
