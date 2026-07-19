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
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var selectedSpecies: String
    @State private var customSpecies: String
    @State private var weight: String
    @State private var length: String
    @State private var caughtAt: Date
    @State private var location: String
    @State private var lureText: String
    @State private var rodReel: String
    @State private var notes: String
    @State private var released: Bool
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
        _lureText = State(initialValue: values?.lureText ?? "")
        _rodReel = State(initialValue: values?.rodReel ?? "")
        _notes = State(initialValue: values?.notes ?? "")
        _released = State(initialValue: values?.released ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    speciesSection
                    measurementSection
                    caughtSection
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
                    Button("Cancel") { dismiss() }
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
        .alert("Catch not saved", isPresented: Binding(
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
            TextField("Named spot", text: $location)
                .textInputAutocapitalization(.words)
                .fieldInputStyle()
                .accessibilityIdentifier("add.location")
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
        Button(species) {
            selectedSpecies = species
            customSpecies = ""
        }
        .font(ReelFont.body(.subheadline, weight: .semibold))
        .foregroundStyle(selectedSpecies == species ? ReelTheme.accentInk : ReelTheme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            selectedSpecies == species ? ReelTheme.accent : ReelTheme.raisedSurface,
            in: Capsule()
        )
        .overlay { Capsule().stroke(selectedSpecies == species ? Color.clear : ReelTheme.border) }
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
        do {
            let values = try CatchValues(
                species: finalSpecies,
                weight: CatchFormatting.parseOptionalMeasurement(weight, field: .weight),
                length: CatchFormatting.parseOptionalMeasurement(length, field: .length),
                caughtAt: caughtAt,
                location: location,
                lureText: lureText,
                rodReel: rodReel,
                notes: notes,
                released: released
            )
            if let editItem {
                try repository.update(id: editItem.id, ownerID: ownerID, values: values)
            } else {
                try repository.create(NewCatch(ownerID: ownerID, values: values))
            }
            onSaved()
            dismiss()
            Task { await syncCoordinator.sync(ownerID: ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
