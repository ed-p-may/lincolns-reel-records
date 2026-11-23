import SwiftUI

struct TacklePickerView: View {
    @State private var query = ""
    @State private var selectedType: TackleItemType?
    @State private var isAddingItem = false

    let ownerID: UUID
    let items: [TackleItem]
    let recentItems: [TackleItem]
    let selectedItemID: UUID?
    let onSelect: (TackleItem) -> Void
    let onCreated: (TackleItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        let selectable = items.filter(\.isSelectable)
        let selectableRecent = recentItems.filter(\.isSelectable)
        let types = TackleDiscovery.availableTypes(in: selectable)
        let isFiltering = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedType != nil
        let showsRecent = !selectableRecent.isEmpty && !isFiltering
        let sections = TackleDiscovery.sectionsByType(in: selectable, query: query, type: selectedType)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectable.isEmpty {
                        emptyCatalogState
                    } else {
                        searchField
                        typeFilterBar(types: types)
                        if !showsRecent, sections.isEmpty {
                            noMatchesState
                        } else {
                            galleryGrid(
                                recent: showsRecent ? selectableRecent : [],
                                sections: sections
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ReelTheme.background)
            .navigationTitle("Choose Lure / Bait")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("tackle.picker.cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAddingItem = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add tackle item")
                    .accessibilityIdentifier("tackle.picker.add")
                }
            }
            .sheet(isPresented: $isAddingItem) {
                TackleItemEditor(ownerID: ownerID) { item in
                    onCreated(item)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Search lures, brands, colors", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("tackle.picker.search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ReelTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(ReelTheme.border) }
    }

    private func typeFilterBar(types: [TackleItemType]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectionChip(title: "All", isSelected: selectedType == nil, sizing: .compact) {
                    selectedType = nil
                }
                .accessibilityIdentifier("tackle.picker.type.all")
                ForEach(types) { type in
                    SelectionChip(title: type.label, isSelected: selectedType == type, sizing: .compact) {
                        selectedType = type
                    }
                    .accessibilityIdentifier("tackle.picker.type.\(type.rawValue)")
                }
            }
        }
    }

    private func galleryGrid(
        recent: [TackleItem],
        sections: [TackleTypeSection]
    ) -> some View {
        LazyVGrid(columns: columns, spacing: 13) {
            if !recent.isEmpty {
                Section {
                    ForEach(recent) { item in
                        Button { onSelect(item) } label: {
                            TackleItemCard(item: item, isSelected: item.id == selectedItemID)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tackle.picker.recent.\(item.id.uuidString)")
                    }
                } header: {
                    TackleSectionHeader(
                        title: "Recently Used",
                        systemImage: "clock.arrow.circlepath",
                        count: recent.count,
                        identifier: "tackle.picker.section.recent"
                    )
                }
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        Button { onSelect(item) } label: {
                            TackleItemCard(item: item, isSelected: item.id == selectedItemID)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tackle.picker.item.\(item.id.uuidString)")
                    }
                } header: {
                    TackleSectionHeader(
                        title: section.type.label,
                        systemImage: section.type.systemImage,
                        count: section.items.count,
                        identifier: "tackle.picker.section.\(section.type.rawValue)"
                    )
                }
            }
        }
    }

    private var emptyCatalogState: some View {
        ContentUnavailableView {
            Label("Your Tackle Box is ready", systemImage: "shippingbox")
        } description: {
            Text("Add a lure or bait once, then reuse it while logging.")
        } actions: {
            Button("Add Tackle") { isAddingItem = true }
                .buttonStyle(.borderedProminent)
                .tint(ReelTheme.accent)
                .foregroundStyle(ReelTheme.accentInk)
                .accessibilityIdentifier("tackle.picker.empty.add")
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var noMatchesState: some View {
        ContentUnavailableView {
            Label("No matching tackle", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search or clear your filters.")
        } actions: {
            Button("Clear Filters") {
                query = ""
                selectedType = nil
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("tackle.picker.clear-filters")

            Button("Add Tackle") { isAddingItem = true }
                .buttonStyle(.borderedProminent)
                .tint(ReelTheme.accent)
                .foregroundStyle(ReelTheme.accentInk)
                .accessibilityIdentifier("tackle.picker.empty.add")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    }
}
