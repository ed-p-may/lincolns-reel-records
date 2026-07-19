import SwiftUI

struct LogbookView: View {
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catches: [CatchItem] = []
    @State private var loadError: String?

    let ownerID: UUID
    let refreshToken: Int
    let onAddCatch: () -> Void
    let onOpenCatch: (CatchItem) -> Void

    var body: some View {
        Group {
            if catches.isEmpty, loadError == nil {
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
            } else {
                List(catches) { catchItem in
                    Button {
                        onOpenCatch(catchItem)
                    } label: {
                        CatchRow(catchItem: catchItem)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(ReelTheme.surface)
                    .listRowSeparatorTint(ReelTheme.border)
                }
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("log.catch-list")
            }
        }
        .background(ReelTheme.background)
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("\(catches.count) RECORD\(catches.count == 1 ? "" : "S")")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
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
        .safeAreaInset(edge: .bottom) {
            if let statusMessage = syncCoordinator.statusMessage {
                Label(statusMessage, systemImage: "wifi.exclamationmark")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .task(id: refreshToken + syncCoordinator.revision) {
            reload()
        }
        .alert("Unable to open logbook", isPresented: .constant(loadError != nil)) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private func reload() {
        do {
            catches = try repository.list(ownerID: ownerID)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct CatchRow: View {
    let catchItem: CatchItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "fish.fill")
                .font(.title2)
                .foregroundStyle(ReelTheme.accentHighlight)
                .frame(width: 44, height: 44)
                .background(ReelTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(catchItem.species)
                    .font(ReelFont.display(17))
                    .foregroundStyle(ReelTheme.primaryText)
                Text(catchItem.caughtAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ReelFont.metadata(.caption))
                    .foregroundStyle(ReelTheme.secondaryText)
                Text(catchItem.summary)
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            SyncBadge(state: catchItem.syncState)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("catch.\(catchItem.id.uuidString)")
    }
}

private struct SyncBadge: View {
    let state: CatchSyncState

    var body: some View {
        Label(state.label, systemImage: state.systemImage)
            .labelStyle(.iconOnly)
            .font(.caption)
            .foregroundStyle(color)
            .accessibilityLabel(state.label)
    }

    private var color: Color {
        switch state {
        case .pending, .syncing: ReelTheme.secondaryText
        case .synced: ReelTheme.accent
        case .failed, .conflict: ReelTheme.danger
        }
    }
}

private extension CatchItem {
    var summary: String {
        [
            weight.map(CatchFormatting.weight),
            length.map(CatchFormatting.length),
            location,
            lureText,
            released ? "Released" : "Kept"
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}
