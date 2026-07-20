import SwiftUI

struct TackleItemCard: View {
    @Environment(SwiftDataTackleRepository.self) private var repository

    let item: TackleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                LocalPhotoImage(
                    url: repository.fileURL(for: item),
                    maximumPixelSize: 480,
                    contentMode: .fill,
                    placeholder: TacklePhotoPlaceholder(type: item.type)
                )
                .frame(height: 116)
                .clipped()

                HStack(alignment: .top) {
                    Text(item.type.label)
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 24)
                        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 7))
                    Spacer()
                    Circle()
                        .fill(TackleColor.swatch(item.color))
                        .frame(width: 19, height: 19)
                        .overlay { Circle().stroke(.white.opacity(0.55), lineWidth: 2) }
                        .accessibilityLabel(item.color.map { "Color \($0)" } ?? "Color not recorded")
                }
                .padding(9)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                Text(metadata)
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
                    .lineLimit(2)
                if item.archived || item.deletedAt != nil {
                    Text(item.deletedAt == nil ? "ARCHIVED" : "UNAVAILABLE")
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .foregroundStyle(ReelTheme.secondaryText)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 23)
                        .background(ReelTheme.raisedSurface, in: Capsule())
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(11)
        }
        .background(ReelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var metadata: String {
        let details = [item.size, item.brand].compactMap(\.self).joined(separator: " · ")
        return details.isEmpty ? item.type.label : details
    }
}

struct TackleItemRow: View {
    @Environment(SwiftDataTackleRepository.self) private var repository

    let item: TackleItem
    var isSelected = false

    var body: some View {
        HStack(spacing: 12) {
            LocalPhotoImage(
                url: repository.fileURL(for: item),
                maximumPixelSize: 180,
                contentMode: .fill,
                placeholder: TacklePhotoPlaceholder(type: item.type)
            )
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                Text([item.type.label, item.size].compactMap(\.self).joined(separator: " · "))
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
                    .lineLimit(1)
                if item.archived || item.deletedAt != nil {
                    Text(item.deletedAt == nil ? "ARCHIVED" : "UNAVAILABLE")
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(ReelTheme.accentInk)
                    .frame(width: 28, height: 28)
                    .background(ReelTheme.accent, in: Circle())
            }
        }
        .padding(11)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? ReelTheme.accent : ReelTheme.border, lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct TacklePhotoPlaceholder: View {
    let type: TackleItemType

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ReelTheme.raisedSurface, ReelTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: type.systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(ReelTheme.primaryText.opacity(0.18))
        }
        .accessibilityHidden(true)
    }
}

enum TackleColor {
    private static let namedSwatches: [(keyword: String, color: Color)] = [
        ("chartreuse", Color(red: 0.82, green: 0.95, blue: 0.22)),
        ("black", .black),
        ("blue", .blue),
        ("green", .green.opacity(0.65)),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("pink", .pink),
        ("purple", .purple),
        ("white", Color(white: 0.88)),
        ("bone", Color(white: 0.88)),
        ("brown", Color(red: 0.42, green: 0.45, blue: 0.25)),
        ("pumpkin", Color(red: 0.42, green: 0.45, blue: 0.25))
    ]

    static func swatch(_ name: String?) -> Color {
        guard let name = name?.lowercased() else { return ReelTheme.tertiaryText }
        return namedSwatches.first { name.contains($0.keyword) }?.color ?? ReelTheme.secondaryText
    }
}
