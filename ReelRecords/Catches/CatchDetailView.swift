import SwiftUI

struct CatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    measurementSummary
                    catchDetails
                    fieldNotes
                    recordStatus
                    deleteButton
                }
                .padding(.bottom, 28)
            }
            .background(ReelTheme.background)
            .navigationTitle(catchItem.species)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
        .alert("Catch not changed", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CatchPhotoPlaceholder(species: catchItem.species)
            LinearGradient(
                colors: [ReelTheme.page.opacity(0.05), ReelTheme.background],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 7) {
                Text("PERSONAL LOG")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ReelTheme.accentHighlight)
                Text(catchItem.species)
                    .font(ReelFont.display(32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                HStack(spacing: 12) {
                    Label(catchItem.location ?? "Spot not recorded", systemImage: "location.fill")
                    Label(
                        catchItem.caughtAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                }
                .font(ReelFont.body(.caption))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            }
            .padding(20)
        }
        .frame(minHeight: 300)
        .clipped()
    }

    private var measurementSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { metricCards }
            VStack(spacing: 12) { metricCards }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var metricCards: some View {
        DetailMetricCard(
            label: "Weight",
            value: catchItem.weight.map(CatchFormatting.weight),
            systemImage: "trophy.fill",
            prominent: true
        )
        DetailMetricCard(
            label: "Length",
            value: catchItem.length.map(CatchFormatting.length),
            systemImage: "ruler",
            prominent: false
        )
    }

    private var catchDetails: some View {
        DetailSection(title: "Catch details") {
            LazyVGrid(columns: detailColumns, spacing: 11) {
                DetailTile(
                    label: "Lure / bait",
                    value: catchItem.lureText,
                    systemImage: "fish.fill"
                )
                DetailTile(
                    label: "Rod & reel",
                    value: catchItem.rodReel,
                    systemImage: "wrench.and.screwdriver.fill"
                )
                DetailTile(
                    label: "Disposition",
                    value: catchItem.released ? "Released" : "Kept",
                    systemImage: catchItem.released ? "arrow.uturn.backward" : "checkmark.circle.fill"
                )
                DetailTile(
                    label: "Caught",
                    value: catchItem.caughtAt.formatted(date: .long, time: .shortened),
                    systemImage: "calendar"
                )
            }
        }
    }

    private var detailColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var fieldNotes: some View {
        DetailSection(title: "Field notes") {
            Text(catchItem.notes ?? "No field notes recorded.")
                .font(ReelFont.body())
                .foregroundStyle(catchItem.notes == nil ? ReelTheme.tertiaryText : ReelTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var recordStatus: some View {
        DetailSection(title: "Record status") {
            HStack(spacing: 10) {
                SyncBadge(state: catchItem.syncState)
                VStack(alignment: .leading, spacing: 2) {
                    Text(catchItem.syncState.label)
                        .font(ReelFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(ReelTheme.primaryText)
                    if let syncError = catchItem.syncError {
                        Text(syncError)
                            .font(ReelFont.body(.caption))
                            .foregroundStyle(ReelTheme.danger)
                    }
                }
                Spacer()
                Text("v\(catchItem.remoteVersion)")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var deleteButton: some View {
        Button("Delete Catch", role: .destructive) {
            isConfirmingDelete = true
        }
        .font(ReelFont.body(.body, weight: .semibold))
        .foregroundStyle(ReelTheme.danger)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .accessibilityIdentifier("detail.delete")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("detail.done")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Edit") { isEditing = true }
                .accessibilityIdentifier("detail.edit")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                }
            }
        )
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

private struct DetailMetricCard: View {
    let label: String
    let value: String?
    let systemImage: String
    let prominent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label.uppercased(), systemImage: systemImage)
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .foregroundStyle(prominent ? ReelTheme.accentHighlight : ReelTheme.secondaryText)
            Text(value ?? "Not recorded")
                .font(ReelFont.display(value == nil ? 15 : 25, weight: .heavy))
                .foregroundStyle(value == nil ? ReelTheme.tertiaryText : textColor)
                .minimumScaleFactor(0.72)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(16)
        .background(prominent ? ReelTheme.accent.opacity(0.13) : ReelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(prominent ? ReelTheme.accent.opacity(0.25) : ReelTheme.border)
        }
    }

    private var textColor: Color {
        prominent ? .white : ReelTheme.primaryText
    }
}

private struct DetailTile: View {
    let label: String
    let value: String?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(label, systemImage: systemImage)
                .font(ReelFont.body(.caption, weight: .semibold))
                .foregroundStyle(ReelTheme.tertiaryText)
            Text(value ?? "Not recorded")
                .font(ReelFont.body(.subheadline, weight: .semibold))
                .foregroundStyle(value == nil ? ReelTheme.tertiaryText : ReelTheme.primaryText)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(13)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ReelFont.display(17))
                .foregroundStyle(ReelTheme.primaryText)
            content
        }
        .padding(.horizontal, 20)
    }
}
