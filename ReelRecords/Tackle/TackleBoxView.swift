import SwiftUI

private enum TackleEditorDestination: Identifiable {
    case create
    case edit(TackleItem)

    var id: String {
        switch self {
        case .create: "create"
        case let .edit(item): "edit-\(item.id.uuidString)"
        }
    }
}

private struct TackleLoadRequest: Hashable {
    let showsArchived: Bool
    let syncRevision: Int
}

struct TackleBoxView: View {
    @Environment(SwiftDataTackleRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var items: [TackleItem] = []
    @State private var query = ""
    @State private var selectedType: TackleItemType?
    @State private var showsArchived = false
    @State private var editor: TackleEditorDestination?
    @State private var loadError: String?
    @State private var didOpenInitialItem = false

    let ownerID: UUID
    var initialItemID: UUID?

    var body: some View {
        let results = TackleDiscovery.results(in: items, query: query, type: selectedType)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header
                Picker("Catalog", selection: $showsArchived) {
                    Text("Active").tag(false)
                    Text("Archived").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("tackle.archive-filter")

                searchField
                typeFilters
                if results.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(results) { item in
                            Button { editor = .edit(item) } label: {
                                TackleItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tackle.item.\(item.id.uuidString)")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(ReelTheme.background)
        .navigationTitle("Tackle Box")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = .create } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add tackle item")
                    .accessibilityIdentifier("tackle.add")
            }
        }
        .sheet(item: $editor) { destination in
            switch destination {
            case .create:
                TackleItemEditor(ownerID: ownerID) { _ in reload() }
            case let .edit(item):
                TackleItemEditor(ownerID: ownerID, editItem: item) { _ in reload() }
            }
        }
        .task(id: TackleLoadRequest(
            showsArchived: showsArchived,
            syncRevision: syncCoordinator.revision
        )) {
            reload()
            openInitialItemIfNeeded()
        }
        .alert("Unable to open Tackle Box", isPresented: Binding(
            get: { loadError != nil },
            set: {
                if !$0 {
                    loadError = nil
                }
            }
        )) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR GEAR")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(ReelTheme.accentHighlight)
                Text(showsArchived ? "Retired tackle" : "Ready for the water")
                    .font(ReelFont.display(24, weight: .heavy))
                    .foregroundStyle(ReelTheme.primaryText)
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            Spacer()
            if syncCoordinator.isSyncing {
                ProgressView().tint(ReelTheme.accent)
            }
        }
        .padding(.top, 12)
        .accessibilityIdentifier("tackle.header")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Search your tackle", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(ReelTheme.border) }
        .accessibilityIdentifier("tackle.search")
    }

    private var typeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectionChip(title: "All", isSelected: selectedType == nil, sizing: .compact) {
                    selectedType = nil
                }
                .accessibilityIdentifier("tackle.type.all")
                ForEach(TackleItemType.allCases) { type in
                    SelectionChip(title: type.label, isSelected: selectedType == type, sizing: .compact) {
                        selectedType = type
                    }
                    .accessibilityIdentifier("tackle.type.\(type.rawValue)")
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                showsArchived ? "No archived tackle" : "Your Tackle Box is ready",
                systemImage: "shippingbox"
            )
        } description: {
            Text(
                showsArchived
                    ? "Archived gear stays here for history."
                    : "Add a lure or bait once, then reuse it while logging."
            )
        } actions: {
            if !showsArchived {
                Button("Add Tackle") { editor = .create }
                    .buttonStyle(.borderedProminent)
                    .tint(ReelTheme.accent)
                    .foregroundStyle(ReelTheme.accentInk)
                    .accessibilityIdentifier("tackle.empty.add")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    }

    private func reload() {
        do {
            items = try repository.items(ownerID: ownerID, archived: showsArchived)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func openInitialItemIfNeeded() {
        guard !didOpenInitialItem, let initialItemID else { return }
        do {
            guard let item = try repository.item(id: initialItemID, ownerID: ownerID) else { return }
            didOpenInitialItem = true
            editor = .edit(item)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
