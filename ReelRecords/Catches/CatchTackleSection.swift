import SwiftUI

struct CatchTackleSection: View {
    @Environment(SwiftDataTackleRepository.self) private var repository

    let items: [TackleItem]
    @Binding var selectedItemID: UUID?
    @Binding var lureText: String
    let onAdd: () -> Void
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LURE / BAIT")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(1)
                .foregroundStyle(ReelTheme.tertiaryText)
            if let selectedItem {
                Button { selectedItemID = nil } label: {
                    TackleItemRow(item: selectedItem, isSelected: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Selected \(selectedItem.name). Tap to clear.")
                .accessibilityIdentifier("add.tackle.selected")
            }
            itemPicker
            manageButton
            TextField("One-off lure or bait (optional)", text: $lureText)
                .fieldInputStyle()
                .accessibilityIdentifier("add.lure")
            Text("Free text stays available for one-offs, even when a saved item is selected.")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
    }

    private var selectedItem: TackleItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    private var itemPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 11) {
                addButton
                ForEach(items.filter(\.isSelectable)) { item in
                    itemButton(item)
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            VStack(spacing: 7) {
                Image(systemName: "plus")
                Text("New lure")
                    .font(ReelFont.body(.caption, weight: .bold))
            }
            .foregroundStyle(ReelTheme.accentHighlight)
            .frame(width: 96, height: 92)
            .background(ReelTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ReelTheme.accent.opacity(0.45), style: StrokeStyle(dash: [5]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add.tackle.new")
    }

    private func itemButton(_ item: TackleItem) -> some View {
        Button { selectedItemID = item.id } label: {
            VStack(alignment: .leading, spacing: 6) {
                LocalPhotoImage(
                    url: repository.fileURL(for: item),
                    maximumPixelSize: 240,
                    contentMode: .fill,
                    placeholder: TacklePhotoPlaceholder(type: item.type)
                )
                .frame(width: 96, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                Text(item.name)
                    .font(ReelFont.body(.caption, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                    .frame(width: 96, alignment: .leading)
            }
            .padding(7)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedItemID == item.id ? ReelTheme.accent : ReelTheme.border)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add.tackle.\(item.id.uuidString)")
    }

    private var manageButton: some View {
        Button(action: onManage) {
            HStack {
                Label("Manage Tackle Box", systemImage: "shippingbox.fill")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(ReelFont.body(.subheadline, weight: .semibold))
            .foregroundStyle(ReelTheme.secondaryText)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(ReelTheme.border) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add.tackle.manage")
    }
}
