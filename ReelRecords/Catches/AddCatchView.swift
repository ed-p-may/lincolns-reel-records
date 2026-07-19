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
    @State private var selectedSpecies = ""
    @State private var customSpecies = ""
    @State private var caughtAt = Date.now
    @State private var errorMessage: String?

    let ownerID: UUID
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    fieldLabel("Caught")
                    DatePicker(
                        "Date and time",
                        selection: $caughtAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(ReelTheme.accent)
                    .padding(14)
                    .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("add.caught-at")

                    Text("Species and caught date/time are the only required fields in this first build.")
                        .font(ReelFont.body(.footnote))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
                .padding(20)
            }
            .background(ReelTheme.background)
            .navigationTitle("Log a Catch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save Catch", systemImage: "checkmark") {
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

    private func save() {
        do {
            try repository.create(NewCatch(ownerID: ownerID, species: finalSpecies, caughtAt: caughtAt))
            onSaved()
            dismiss()
            Task { await syncCoordinator.sync(ownerID: ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
