import SwiftUI

struct CatchMeasurementEditor: View {
    @Binding var weight: String
    @Binding var length: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Measurements")
            HStack(spacing: 12) {
                UnitInput(
                    "Weight",
                    unit: "lb",
                    text: $weight,
                    keyboardType: .decimalPad,
                    identifier: "add.weight"
                )
                UnitInput(
                    "Length",
                    unit: "in",
                    text: $length,
                    keyboardType: .decimalPad,
                    identifier: "add.length"
                )
            }
        }
    }
}

struct CatchDateEditor: View {
    @Binding var caughtAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Caught")
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
}

struct CatchSpeciesEditor: View {
    static let suggestedSpecies = [
        "Largemouth Bass",
        "Smallmouth Bass",
        "Northern Pike",
        "Walleye",
        "Crappie",
        "Bluegill",
        "Channel Catfish",
        "Rainbow Trout"
    ]

    let options: [String]
    @Binding var selectedSpecies: String
    @Binding var customSpecies: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Species")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 10) {
                ForEach(options, id: \.self) { species in
                    SelectionChip(title: species, isSelected: selectedSpecies == species, sizing: .fillWidth) {
                        selectedSpecies = species
                        customSpecies = ""
                    }
                    .accessibilityIdentifier("add.species.\(species)")
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
}

struct CatchDetailsEditor: View {
    @Binding var rodReel: String
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Details")
            TextField("Rod and reel", text: $rodReel)
                .fieldInputStyle()
                .accessibilityIdentifier("add.rod-reel")
            TextField("Field notes", text: $notes, axis: .vertical)
                .lineLimit(4 ... 8)
                .fieldInputStyle()
                .accessibilityIdentifier("add.notes")
        }
    }
}

struct CatchDispositionEditor: View {
    @Binding var released: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddCatchFieldLabel("Disposition")
            Picker("Disposition", selection: $released) {
                Text("Released").tag(true)
                Text("Kept").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("add.released")
        }
    }
}

struct AddCatchTacklePresentations: ViewModifier {
    let ownerID: UUID
    let items: [TackleItem]
    let recentItems: [TackleItem]
    let selectedItemID: UUID?
    @Binding var isAdding: Bool
    @Binding var isBrowsing: Bool
    @Binding var isManaging: Bool
    let onSelect: (TackleItem) -> Bool
    let onCreated: (TackleItem) -> Void
    let onReload: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isAdding) {
                TackleItemEditor(ownerID: ownerID, onSaved: onCreated)
            }
            .fullScreenCover(isPresented: $isBrowsing) {
                TacklePickerView(
                    ownerID: ownerID,
                    items: items,
                    recentItems: recentItems,
                    selectedItemID: selectedItemID,
                    onSelect: {
                        if onSelect($0) {
                            isBrowsing = false
                        }
                    },
                    onCreated: {
                        onCreated($0)
                        isBrowsing = false
                    },
                    onCancel: { isBrowsing = false }
                )
            }
            .fullScreenCover(isPresented: $isManaging) {
                NavigationStack {
                    TackleBoxView(ownerID: ownerID)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    onReload()
                                    isManaging = false
                                }
                            }
                        }
                }
            }
    }
}

struct AddCatchFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .tracking(1)
            .foregroundStyle(ReelTheme.tertiaryText)
    }
}
