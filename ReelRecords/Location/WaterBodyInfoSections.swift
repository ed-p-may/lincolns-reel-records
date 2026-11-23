import MapKit
import SwiftUI

struct WaterBodyPeekPill: Identifiable {
    let id: String
    let label: String
    let icon: String?
    let tint: Color
}

struct WaterBodyHeaderView: View {
    let selection: WaterBodySelection
    let localHistory: LocalWaterHistory
    let info: WaterBodyInfo?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if let thumbURL = info?.heroThumbnailURL {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()
                        default:
                            waterIconBadge
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    waterIconBadge
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(selection.name)
                        .reelDisplayFont(21)
                        .foregroundStyle(ReelTheme.primaryText)
                        .lineLimit(2)
                        .accessibilityIdentifier("water-sheet.title")
                    Text(selection.subtitle)
                        .font(ReelFont.metadata(.caption, weight: .semibold))
                        .foregroundStyle(ReelTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ReelTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close water body info")
                .accessibilityIdentifier("water-sheet.dismiss")
            }

            if !peekPills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(peekPills) { pill in
                            HStack(spacing: 4) {
                                if let icon = pill.icon {
                                    Image(systemName: icon)
                                        .font(.caption2)
                                }
                                Text(pill.label)
                                    .font(ReelFont.metadata(.caption2, weight: .bold))
                            }
                            .foregroundStyle(pill.tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(pill.tint.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var waterIconBadge: some View {
        Image(systemName: selection.waterType.systemImage)
            .font(.title3)
            .foregroundStyle(ReelTheme.accessPin)
            .frame(width: 52, height: 52)
            .background(ReelTheme.accessPin.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var peekPills: [WaterBodyPeekPill] {
        var pills: [WaterBodyPeekPill] = []
        if localHistory.catchCount > 0 {
            let word = localHistory.catchCount == 1 ? "catch" : "catches"
            pills.append(WaterBodyPeekPill(
                id: "local-catches",
                label: "Your history: \(localHistory.catchCount) \(word)",
                icon: "fish.fill",
                tint: ReelTheme.accent
            ))
        }
        if let flow = info?.riverGauge?.compactFlowLabel {
            let isStale = info?.isRiverGaugeStale == true || info?.isFromOfflineCache == true
            pills.append(WaterBodyPeekPill(
                id: "river-flow",
                label: isStale ? "\(flow) (saved)" : flow,
                icon: "water.waves",
                tint: ReelTheme.accessPin
            ))
        }
        if let species = info?.species {
            for item in species.prefix(3) {
                pills.append(WaterBodyPeekPill(
                    id: "species-\(item.id)",
                    label: item.commonName,
                    icon: nil,
                    tint: ReelTheme.primaryText
                ))
            }
        }
        return pills
    }
}

struct LocalWaterHistorySection: View {
    let history: LocalWaterHistory
    let onOpenCatch: (CatchItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            waterSectionHeader("YOUR HISTORY HERE", icon: "book.closed.fill", tint: ReelTheme.accent)

            HStack(spacing: 12) {
                statPill(title: "Catches", value: "\(history.catchCount)")
                if let bestWeight = history.personalBestWeight {
                    statPill(title: "Best Weight", value: CatchFormatting.weight(bestWeight))
                }
                if let bestLength = history.personalBestLength {
                    statPill(title: "Best Length", value: CatchFormatting.length(bestLength))
                }
            }

            if !history.topLures.isEmpty {
                Text("Top lures: \(history.topLures.joined(separator: ", "))")
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.secondaryText)
            }

            if let latest = history.recentCatches.first {
                Button {
                    onOpenCatch(latest)
                } label: {
                    HStack(spacing: 8) {
                        Text("Latest: \(latest.species)")
                            .font(ReelFont.body(.caption, weight: .semibold))
                            .foregroundStyle(ReelTheme.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Text(latest.caughtAt.formatted(date: .abbreviated, time: .omitted))
                            .font(ReelFont.metadata(.caption2))
                            .foregroundStyle(ReelTheme.tertiaryText)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(ReelTheme.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.accent.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.local-history")
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
            Text(value)
                .font(ReelFont.body(.subheadline, weight: .bold))
                .foregroundStyle(ReelTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WaterBodyOverviewSection: View {
    let overview: String
    let wikipediaURL: URL?
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader("OVERVIEW", icon: "info.circle.fill", tint: ReelTheme.accessPin)
            Text(overview)
                .font(ReelFont.body(.subheadline))
                .foregroundStyle(ReelTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let wikipediaURL {
                Button {
                    onOpenURL(wikipediaURL)
                } label: {
                    Label("Read on Wikipedia", systemImage: "arrow.up.right.square")
                        .font(ReelFont.metadata(.caption, weight: .semibold))
                        .foregroundStyle(ReelTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.overview")
    }
}

struct RiverGaugeSection: View {
    let gauge: RiverGaugeReading
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader(
                isStale ? "LAST KNOWN RIVER CONDITIONS · USGS" : "LIVE RIVER CONDITIONS · USGS",
                icon: "water.waves",
                tint: ReelTheme.accessPin
            )
            Text(gauge.siteName)
                .font(ReelFont.body(.caption, weight: .semibold))
                .foregroundStyle(ReelTheme.secondaryText)
            HStack(spacing: 12) {
                if let flow = gauge.compactFlowLabel {
                    metricBox(label: "Flow", value: flow)
                }
                if let height = gauge.gaugeHeightLabel {
                    metricBox(label: "Gauge", value: height)
                }
                if let temp = gauge.waterTemperatureLabel {
                    metricBox(label: "Water Temp", value: temp)
                }
            }
            if let observedAt = gauge.observedAt {
                Text("Reading \(observedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.river-gauge")
    }

    private func metricBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ReelFont.metadata(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
            Text(value)
                .font(ReelFont.body(.subheadline, weight: .bold))
                .foregroundStyle(ReelTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WaterBodyAccessSection: View {
    let accessPoints: [WaterBodyAccessPoint]
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader("BOAT RAMPS & ACCESS · OPENSTREETMAP", icon: "sailboat.fill", tint: ReelTheme.accessPin)
            ForEach(accessPoints) { point in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.name)
                            .font(ReelFont.body(.subheadline, weight: .semibold))
                            .foregroundStyle(ReelTheme.primaryText)
                        Text(point.kind)
                            .font(ReelFont.metadata(.caption2))
                            .foregroundStyle(ReelTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        let placemark = MKPlacemark(coordinate: point.coordinate.mapCoordinate)
                        let item = MKMapItem(placemark: placemark)
                        item.name = point.name
                        item.openInMaps(launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                        ])
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .foregroundStyle(ReelTheme.accessPin)
                            .padding(8)
                            .background(ReelTheme.raisedSurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Directions to \(point.name)")
                }
            }
            Button {
                if let url = URL.validatedWebURL("https://www.openstreetmap.org/copyright") {
                    onOpenURL(url)
                }
            } label: {
                Text("Source: OpenStreetMap contributors (ODbL)")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.access")
    }
}

struct WaterBodySpeciesSection: View {
    let species: [WaterBodySpecies]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader(
                "NEARBY FISH OBSERVATIONS (3 KM) · INATURALIST",
                icon: "fish.fill",
                tint: ReelTheme.accent
            )
            Text("From recent iNaturalist sample within 3 km; verify for this specific water.")
                .font(ReelFont.body(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(species) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.commonName)
                                .font(ReelFont.body(.caption, weight: .semibold))
                                .foregroundStyle(ReelTheme.primaryText)
                            Text("\(item.observationCount) obs")
                                .font(ReelFont.metadata(.caption2))
                                .foregroundStyle(ReelTheme.tertiaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.species")
    }
}

struct WaterBodyPhotosSection: View {
    let photos: [WaterBodyPhoto]
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader("NEARBY PUBLIC PHOTOS", icon: "photo.on.rectangle.angled", tint: ReelTheme.accessPin)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos) { photo in
                        CachedWaterPhotoTile(photo: photo, onOpenURL: onOpenURL)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.photos")
    }
}

struct WaterBodyExploreLinksSection: View {
    let links: [WaterBodyQuickLink]
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            waterSectionHeader("EXPLORE FURTHER", icon: "safari.fill", tint: ReelTheme.accent)
            ForEach(links) { link in
                Button {
                    onOpenURL(link.url)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: link.systemImage)
                            .foregroundStyle(ReelTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title)
                                .font(ReelFont.body(.subheadline, weight: .semibold))
                                .foregroundStyle(ReelTheme.primaryText)
                            Text(link.subtitle)
                                .font(ReelFont.body(.caption2))
                                .foregroundStyle(ReelTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(ReelTheme.tertiaryText)
                    }
                    .padding(10)
                    .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.explore-links")
    }
}

func waterSectionHeader(_ title: String, icon: String, tint: Color) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(tint)
        Text(title)
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(ReelTheme.secondaryText)
    }
}
