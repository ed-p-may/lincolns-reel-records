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
    @State private var speciesOptions = Self.suggestedSpecies
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
    @State private var photoMetadataDraft = PhotoMetadataDefaultsDraft()
    @State private var didLoadDefaults = false
    @State private var didLoadSpeciesOptions = false
    @State private var didLoadPhotos = false
    @State private var didCommitPhotos = false
    @State private var didNotifySaved = false
    @State private var persistedCatchID: UUID?
    @State private var isChoosingLocation = false
    @State private var errorMessage: String?
    @State private var initialValues: CatchValues?

    let ownerID: UUID
    let editItem: CatchItem?
    let onSaved: () -> Void

    init(ownerID: UUID, editItem: CatchItem? = nil, onSaved: @escaping () -> Void) {
        self.ownerID = ownerID
        self.editItem = editItem
        self.onSaved = onSaved

        let values = editItem?.values
        _initialValues = State(initialValue: values)
        let species = CatchDiscovery.pickerSelection(for: values?.species ?? "", options: Self.suggestedSpecies)
        _selectedSpecies = State(initialValue: species.selected)
        _customSpecies = State(initialValue: species.custom)
        let numbers = CatchNumberInputs(loading: values)
        _weight = State(initialValue: numbers.weight)
        _length = State(initialValue: numbers.length)
        _caughtAt = State(initialValue: values?.caughtAt ?? .now)
        _location = State(initialValue: values?.location ?? "")
        _coordinate = State(initialValue: values?.coordinate)
        let conditions = values?.conditions ?? .empty
        _airTemperature = State(initialValue: numbers.airTemperature)
        _skyCondition = State(initialValue: conditions.skyCondition)
        _waterTemperature = State(initialValue: numbers.waterTemperature)
        _waterClarity = State(initialValue: conditions.waterClarity)
        _conditionDraft = State(initialValue: ConditionEnrichmentDraft(loading: values))
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
                    CatchPhotoEditor(
                        photos: $photos,
                        sessionID: photoSessionID,
                        onMetadata: applyPhotoMetadata,
                        onError: { errorMessage = $0 }
                    )
                    CatchSpeciesEditor(
                        options: speciesOptions,
                        selectedSpecies: $selectedSpecies,
                        customSpecies: $customSpecies
                    )
                    measurementSection
                    CatchDateEditor(caughtAt: caughtAtBinding)
                    CatchLocationEditor(
                        location: $location,
                        coordinate: coordinateBinding,
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
                    CatchDetailsEditor(rodReel: $rodReel, notes: $notes)
                    CatchDispositionEditor(released: $released)

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
            loadSpeciesOptions()
            loadNewCatchDefaults()
            loadTackleItems()
        }
        .task(id: weatherRequestKey) {
            await suggestWeatherIfNeeded()
        }
        .onChange(of: locationService.state) { _, state in
            if case let .captured(capturedCoordinate, _) = state {
                photoMetadataDraft.markCoordinateManual()
                coordinate = capturedCoordinate
            }
        }
        .sheet(isPresented: $isChoosingLocation) {
            ManualLocationPicker(initialCoordinate: coordinate) { selected in
                locationService.reset()
                photoMetadataDraft.markCoordinateManual()
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

    private var measurementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Measurements")
            HStack(spacing: 12) {
                measurementInput("Weight", unit: "lb", text: $weight, identifier: "add.weight")
                measurementInput("Length", unit: "in", text: $length, identifier: "add.length")
            }
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
}

private extension AddCatchView {
    private var finalSpecies: String {
        let custom = customSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? selectedSpecies : custom
    }

    private var weatherRequestKey: WeatherRequestKey? {
        coordinate.map { WeatherRequestKey(coordinate: $0, caughtAt: caughtAt) }
    }

    private var caughtAtBinding: Binding<Date> {
        Binding(
            get: { caughtAt },
            set: {
                photoMetadataDraft.markCapturedAtManual()
                caughtAt = $0
            }
        )
    }

    private var coordinateBinding: Binding<CatchCoordinate?> {
        Binding(
            get: { coordinate },
            set: {
                photoMetadataDraft.markCoordinateManual()
                coordinate = $0
            }
        )
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

    private func formValues() throws -> CatchValues {
        let numbers = try CatchNumberInputs(
            weight: weight, length: length, airTemperature: airTemperature, waterTemperature: waterTemperature
        ).parsed(unchangedFrom: initialValues)
        return CatchValues(
            species: finalSpecies,
            weight: numbers.weight,
            length: numbers.length,
            caughtAt: caughtAt,
            location: location,
            coordinate: coordinate,
            conditions: CatchConditions(
                airTemperatureF: numbers.airTemperatureF,
                skyCondition: skyCondition,
                waterTemperatureF: numbers.waterTemperatureF,
                waterClarity: waterClarity
            ),
            tackleItemID: selectedTackleItemID,
            lureText: lureText,
            rodReel: rodReel,
            notes: notes,
            released: released,
            bookmarked: editItem?.bookmarked ?? false
        )
    }

    private func save() {
        locationService.reset()
        do {
            let values = try formValues()
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

    private func loadSpeciesOptions() {
        guard !didLoadSpeciesOptions else { return }
        didLoadSpeciesOptions = true
        do {
            speciesOptions = try CatchDiscovery.pickerSpecies(
                suggested: Self.suggestedSpecies,
                in: repository.list(ownerID: ownerID)
            )
            // An edited catch whose custom species is now a chip shows that chip selected.
            if selectedSpecies.isEmpty {
                (selectedSpecies, customSpecies) = CatchDiscovery.pickerSelection(
                    for: customSpecies,
                    options: speciesOptions
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNewCatchDefaults() {
        guard !didLoadDefaults, editItem == nil else { return }
        didLoadDefaults = true
        do {
            guard let latestCatch = try repository.latestSameDayCatch(
                ownerID: ownerID,
                caughtAt: caughtAt
            ) else { return }
            let defaults = NewCatchDefaults(catchItem: latestCatch)
            location = defaults.location ?? ""
            coordinate = nil
            selectedTackleItemID = defaults.tackleItemID
            lureText = defaults.lureText ?? ""
            skyCondition = defaults.skyCondition
            if defaults.skyCondition != nil {
                conditionDraft.markSkyConditionFallback()
            }
            waterClarity = defaults.waterClarity
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPhotoMetadata(_ metadata: PhotoCaptureMetadata) {
        guard editItem == nil else { return }
        let applied = photoMetadataDraft.apply(metadata)
        if let capturedAt = applied.capturedAt {
            caughtAt = capturedAt
        }
        if let coordinate = applied.coordinate {
            locationService.reset()
            self.coordinate = coordinate
        }
    }

    private func loadTackleItems() {
        do {
            var loaded = try tackleRepository.items(ownerID: ownerID)
            if let selectedTackleItemID {
                let isLoaded = loaded.contains { $0.id == selectedTackleItemID }
                if !isLoaded {
                    if let historical = try tackleRepository.item(id: selectedTackleItemID, ownerID: ownerID) {
                        loaded.append(historical)
                    }
                }
            }
            tackleItems = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func suggestWeatherIfNeeded() async {
        weatherSuggestionMessage = nil
        guard let coordinate, let key = weatherRequestKey,
              conditionDraft.shouldRequestWeather(for: key),
              !completedWeatherKeys.contains(key)
        else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(400))
            try Task.checkCancellation()
            fetchingWeatherKey = key
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
