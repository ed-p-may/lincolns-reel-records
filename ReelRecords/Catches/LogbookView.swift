import SwiftUI

struct LogbookView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catches: [CatchItem] = []
    @State private var photosByCatch: [UUID: [CatchPhotoItem]] = [:]
    @State private var searchQuery = ""
    @State private var selectedSpecies: String?
    @State private var sort: CatchSort = .recent
    @State private var loadError: String?

    let ownerID: UUID
    let refreshToken: Int
    let onAddCatch: () -> Void
    let onOpenCatch: (CatchItem) -> Void

    var body: some View {
        let results = CatchDiscovery.results(
            in: catches,
            query: searchQuery,
            species: selectedSpecies,
            sort: sort
        )
        let availableSpecies = CatchDiscovery.species(in: catches)

        return Group {
            if catches.isEmpty, loadError == nil {
                emptyLog
            } else {
                logContent(results: results, availableSpecies: availableSpecies)
            }
        }
        .background(ReelTheme.background)
        .navigationTitle("Fishing Log")
        .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { syncStatus }
        .task(id: refreshToken + syncCoordinator.revision) { reload() }
        .alert("Unable to open logbook", isPresented: errorBinding) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var emptyLog: some View {
        ContentUnavailableView {
            Label("Your logbook is ready", systemImage: "book.closed")
        } description: {
            Text("Save the first catch, even without a signal.")
        } actions: {
            Button("Log a Catch", action: onAddCatch)
                .buttonStyle(.borderedProminent)
                .tint(ReelTheme.accent)
                .foregroundStyle(ReelTheme.accentInk)
                .accessibilityIdentifier("log.empty.add")
        }
    }

    private func logContent(results: [CatchItem], availableSpecies: [String]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                resultCount(resultCount: results.count)
                LogSearchField(text: $searchQuery)
                speciesFilters(availableSpecies: availableSpecies)
                sortControls

                if results.isEmpty {
                    noResults
                } else {
                    ForEach(results) { catchItem in
                        Button {
                            onOpenCatch(catchItem)
                        } label: {
                            CatchCard(
                                catchItem: catchItem,
                                heroPhotoURL: heroPhotoURL(catchID: catchItem.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("catch.\(catchItem.id.uuidString)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("log.catch-list")
    }

    private func resultCount(resultCount: Int) -> some View {
        Group {
            if resultCount == catches.count {
                Text("\(catches.count) IN YOUR RECORDS")
            } else {
                Text("\(resultCount) OF \(catches.count) RECORDS")
            }
        }
        .font(ReelFont.metadata(.caption2, weight: .bold))
        .tracking(0.8)
        .foregroundStyle(ReelTheme.secondaryText)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityIdentifier("log.result-count")
    }

    private func speciesFilters(availableSpecies: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectionChip(title: "All", isSelected: selectedSpecies == nil) {
                    selectedSpecies = nil
                }
                .accessibilityIdentifier("log.species.All")

                ForEach(availableSpecies, id: \.self) { species in
                    SelectionChip(title: species, isSelected: selectedSpecies == species) {
                        selectedSpecies = species
                    }
                    .accessibilityIdentifier("log.species.\(species)")
                }
            }
        }
        .accessibilityLabel("Species filters")
    }

    private var sortControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SORT")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .foregroundStyle(ReelTheme.tertiaryText)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CatchSort.allCases) { choice in
                        SelectionChip(title: choice.title, isSelected: sort == choice, sizing: .compact) {
                            sort = choice
                        }
                        .accessibilityIdentifier("log.sort.\(choice.rawValue)")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var noResults: some View {
        ContentUnavailableView {
            Label("No matching catches", systemImage: "magnifyingglass")
        } description: {
            Text("Try another search or species filter.")
        } actions: {
            Button("Clear filters") {
                searchQuery = ""
                selectedSpecies = nil
            }
            .accessibilityIdentifier("log.clear-filters")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if syncCoordinator.isSyncing {
                ProgressView().tint(ReelTheme.accent)
            } else {
                Button {
                    Task { await syncCoordinator.sync(ownerID: ownerID, confirmingConflicts: true) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Retry sync")
            }
            Button(action: onAddCatch) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Log a catch")
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        if let statusMessage = syncCoordinator.statusMessage {
            Label(statusMessage, systemImage: "wifi.exclamationmark")
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.secondaryText)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: {
                if !$0 {
                    loadError = nil
                }
            }
        )
    }

    private func reload() {
        do {
            catches = try repository.list(ownerID: ownerID)
            photosByCatch = try photoRepository.photosByCatch(ownerID: ownerID)
            let availableSpecies = CatchDiscovery.species(in: catches)
            if let selectedSpecies, !availableSpecies.contains(selectedSpecies) {
                self.selectedSpecies = nil
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func heroPhotoURL(catchID: UUID) -> URL? {
        photosByCatch[catchID]?.first.flatMap(photoRepository.fileURL(for:))
    }
}

private struct LogSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Search species, spot, lure, or notes", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("log.search")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(ReelTheme.tertiaryText)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 52)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(ReelTheme.border, lineWidth: 1)
        }
    }
}
