import SwiftUI

struct CatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catchItem: CatchItem
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    let onChanged: () -> Void

    init(catchItem: CatchItem, onChanged: @escaping () -> Void) {
        _catchItem = State(initialValue: catchItem)
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    measurementSummary
                    details

                    if let notes = catchItem.notes {
                        detailSection("Field notes") {
                            Text(notes)
                                .font(ReelFont.body())
                                .foregroundStyle(ReelTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button("Delete Catch", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .font(ReelFont.body(.body, weight: .semibold))
                    .foregroundStyle(ReelTheme.danger)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("detail.delete")
                }
                .padding(20)
            }
            .background(ReelTheme.background)
            .navigationTitle(catchItem.species)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                        .accessibilityIdentifier("detail.edit")
                }
            }
            .sheet(isPresented: $isEditing) {
                AddCatchView(ownerID: catchItem.ownerID, editItem: catchItem) {
                    reload()
                    onChanged()
                }
            }
            .confirmationDialog(
                "Delete this catch?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Catch", role: .destructive) { deleteCatch() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It disappears now and the deletion syncs when connected.")
            }
        }
        .alert("Catch not changed", isPresented: Binding(
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

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "fish.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(ReelTheme.accentHighlight)
            Text(catchItem.caughtAt.formatted(date: .long, time: .shortened))
                .font(ReelFont.metadata(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
            Label(catchItem.syncState.label, systemImage: catchItem.syncState.systemImage)
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(catchItem.syncState == .conflict ? ReelTheme.danger : ReelTheme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private var measurementSummary: some View {
        if catchItem.weight != nil || catchItem.length != nil {
            HStack(spacing: 12) {
                if let weight = catchItem.weight {
                    stat(CatchFormatting.weight(weight), label: "Weight")
                }
                if let length = catchItem.length {
                    stat(CatchFormatting.length(length), label: "Length")
                }
            }
        }
    }

    private var details: some View {
        detailSection("Catch details") {
            detailRow("Disposition", value: catchItem.released ? "Released" : "Kept")
            if let location = catchItem.location {
                detailRow("Spot", value: location)
            }
            if let lureText = catchItem.lureText {
                detailRow("Lure / bait", value: lureText)
            }
            if let rodReel = catchItem.rodReel {
                detailRow("Rod / reel", value: rodReel)
            }
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(ReelFont.display(24))
                .foregroundStyle(ReelTheme.primaryText)
            Text(label.uppercased())
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func detailSection(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(1)
                .foregroundStyle(ReelTheme.tertiaryText)
            VStack(alignment: .leading, spacing: 12, content: content)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(ReelTheme.secondaryText)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(ReelTheme.primaryText)
        }
        .font(ReelFont.body(.subheadline))
    }

    private func reload() {
        do {
            if let updated = try repository.item(id: catchItem.id, ownerID: catchItem.ownerID) {
                catchItem = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCatch() {
        do {
            try repository.delete(id: catchItem.id, ownerID: catchItem.ownerID)
            onChanged()
            dismiss()
            Task { await syncCoordinator.sync(ownerID: catchItem.ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
