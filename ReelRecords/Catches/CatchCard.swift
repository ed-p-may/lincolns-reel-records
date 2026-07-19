import SwiftUI

struct CatchCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let catchItem: CatchItem

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                regularLayout
            }
        }
        .background(ReelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(ReelTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens catch detail")
    }

    private var regularLayout: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                CatchPhotoPlaceholder(species: catchItem.species)
                LinearGradient(
                    colors: [.clear, ReelTheme.page.opacity(0.92)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                cardBadges
                titleOverlay
            }
            .frame(height: 186)
            .clipped()

            footer
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            CatchPhotoPlaceholder(species: catchItem.species)
                .frame(height: 150)
                .clipped()

            Text(catchItem.species)
                .font(ReelFont.display(22, weight: .heavy))
                .foregroundStyle(ReelTheme.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { measurementBadges }
                VStack(alignment: .leading, spacing: 8) { measurementBadges }
            }

            VStack(alignment: .leading, spacing: 9) {
                Label(catchItem.location ?? "Spot not recorded", systemImage: "location.fill")
                Label(
                    catchItem.caughtAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                )
                Label(catchItem.lureText ?? "Lure not recorded", systemImage: "fish.fill")
            }
            .font(ReelFont.body(.subheadline))
            .foregroundStyle(ReelTheme.secondaryText)

            HStack {
                DispositionBadge(released: catchItem.released)
                Spacer()
                SyncBadge(state: catchItem.syncState)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var measurementBadges: some View {
        if let weight = catchItem.weight {
            MeasurementBadge(text: CatchFormatting.weight(weight), highlighted: true)
        }
        if let length = catchItem.length {
            MeasurementBadge(text: CatchFormatting.length(length))
        }
        if catchItem.weight == nil, catchItem.length == nil {
            Text("Measurements not recorded")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.tertiaryText)
        }
    }

    private var cardBadges: some View {
        VStack {
            HStack(spacing: 7) {
                if let weight = catchItem.weight {
                    MeasurementBadge(text: CatchFormatting.weight(weight), highlighted: true)
                }
                if let length = catchItem.length {
                    MeasurementBadge(text: CatchFormatting.length(length))
                }
                Spacer()
                SyncBadge(state: catchItem.syncState)
            }
            Spacer()
        }
        .padding(12)
    }

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(catchItem.species)
                .font(ReelFont.display(22, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label(catchItem.location ?? "Spot not recorded", systemImage: "location.fill")
                Label(
                    catchItem.caughtAt.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
            }
            .font(ReelFont.body(.caption))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(1)
        }
        .padding(14)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Image(systemName: "fish.fill")
                .foregroundStyle(ReelTheme.accentHighlight)
            Text(catchItem.lureText ?? "Lure not recorded")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
                .lineLimit(1)
            Spacer()
            DispositionBadge(released: catchItem.released)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    private var accessibilitySummary: String {
        [
            catchItem.species,
            catchItem.weight.map(CatchFormatting.weight),
            catchItem.length.map(CatchFormatting.length),
            catchItem.location,
            catchItem.caughtAt.formatted(date: .long, time: .shortened),
            catchItem.lureText,
            catchItem.released ? "Released" : "Kept",
            catchItem.syncState.label
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

struct CatchPhotoPlaceholder: View {
    let species: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 20 / 255, green: 51 / 255, blue: 36 / 255), ReelTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(ReelTheme.accent.opacity(0.08))
                .frame(width: 190, height: 190)
                .offset(x: 100, y: -70)
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 34, weight: .semibold))
                Text("NO PHOTO")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .tracking(1.4)
            }
            .foregroundStyle(ReelTheme.accentHighlight.opacity(0.72))
        }
        .accessibilityLabel("No photo for \(species)")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct MeasurementBadge: View {
    let text: String
    var highlighted = false

    var body: some View {
        Text(text)
            .font(ReelFont.metadata(.caption, weight: .bold))
            .padding(.horizontal, 9)
            .frame(minHeight: 28)
            .foregroundStyle(highlighted ? ReelTheme.accentHighlight : .white)
            .background(
                highlighted ? ReelTheme.accent.opacity(0.18) : ReelTheme.page.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(highlighted ? ReelTheme.accent.opacity(0.4) : ReelTheme.strongBorder)
            }
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

struct DispositionBadge: View {
    let released: Bool

    var body: some View {
        Text(released ? "RELEASED" : "KEPT")
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .padding(.horizontal, 8)
            .frame(minHeight: 26)
            .foregroundStyle(released ? ReelTheme.accentHighlight : ReelTheme.secondaryText)
            .background(released ? ReelTheme.accent.opacity(0.12) : ReelTheme.raisedSurface, in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

struct SyncBadge: View {
    let state: CatchSyncState

    var body: some View {
        Label(state.label, systemImage: state.systemImage)
            .labelStyle(.iconOnly)
            .font(.caption)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(ReelTheme.page.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel(state.label)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var color: Color {
        switch state {
        case .pending, .syncing: ReelTheme.secondaryText
        case .synced: ReelTheme.accent
        case .failed, .conflict: ReelTheme.danger
        }
    }
}
