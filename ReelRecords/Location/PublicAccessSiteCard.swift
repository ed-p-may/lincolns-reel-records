import MapKit
import SwiftUI

struct PublicAccessSiteCard: View {
    let site: PublicAccessSite
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            if !badgeLabels.isEmpty {
                badgeRow
            }
            if hasBodyDetails {
                ViewThatFits(in: .vertical) {
                    detailsBody
                    ScrollView {
                        detailsBody
                    }
                    .frame(maxHeight: 160)
                }
            }
            directionsButton
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.access-site-card")
    }

    private var hasBodyDetails: Bool {
        !detailLines.isEmpty || (site.comments?.isEmpty == false)
    }

    private var detailsBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !detailLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(detailLines, id: \.self) { line in
                        Text(line)
                            .font(ReelFont.body(.caption))
                            .foregroundStyle(ReelTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let comments = site.comments, !comments.isEmpty {
                Text(comments)
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: site.isBoatLaunch ? "sailboat.fill" : "figure.fishing")
                .font(.title3)
                .foregroundStyle(ReelTheme.accessPin)
                .frame(width: 40, height: 40)
                .background(ReelTheme.accessPin.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .reelDisplayFont(17)
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                Text(site.locationSubtitle)
                    .font(ReelFont.metadata(.caption, weight: .semibold))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReelTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(ReelTheme.raisedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close access site details")
            .accessibilityIdentifier("map.access-site-card.close")
        }
    }

    private var badgeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(badgeLabels, id: \.self) { label in
                    Text(label)
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .foregroundStyle(ReelTheme.accessPin)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ReelTheme.accessPin.opacity(0.14), in: Capsule())
                }
            }
        }
    }

    private var directionsButton: some View {
        Button {
            openInAppleMaps()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                Text("Open in Apple Maps")
            }
            .font(ReelFont.body(.subheadline, weight: .semibold))
            .foregroundStyle(ReelTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(ReelTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.access-site-card.directions")
    }

    private var badgeLabels: [String] {
        var labels = site.facilityTypes.map(\.label)
        if site.barrierFree {
            labels.append("Barrier-Free")
        }
        return labels
    }

    private var detailLines: [String] {
        var lines: [String] = []
        if let rampType = site.rampType {
            let laneSuffix = site.lanes.map { " (\($0) lane\($0 == 1 ? "" : "s"))" } ?? ""
            lines.append("Ramp: \(rampType)\(laneSuffix)")
        } else if let lanes = site.lanes {
            lines.append("Lanes: \(lanes)")
        }
        if let parking = site.parking {
            lines.append("Parking: \(parking)")
        }
        if let fee = site.fee, fee.caseInsensitiveCompare("No") != .orderedSame {
            lines.append("Fee: \(fee)")
        }
        if let restricted = site.restricted, restricted.caseInsensitiveCompare("No") != .orderedSame {
            lines.append("Restrictions: \(restricted)")
        }
        if let maintainer = site.maintainer {
            lines.append("Maintained by: \(maintainer)")
        }
        return lines
    }

    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: site.mapCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = site.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

struct PublicAccessPinView: View {
    let site: PublicAccessSite
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Image(systemName: site.isBoatLaunch ? "sailboat.fill" : "figure.fishing")
                .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
                .foregroundStyle(isSelected ? ReelTheme.page : ReelTheme.primaryText)
                .frame(width: isSelected ? 30 : 24, height: isSelected ? 30 : 24)
                .background(
                    isSelected ? ReelTheme.accessPin : ReelTheme.surface.opacity(0.92),
                    in: Circle()
                )
                .overlay {
                    Circle().stroke(ReelTheme.accessPin, lineWidth: isSelected ? 2 : 1.5)
                }
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(site.name) public access")
        .accessibilityIdentifier("map.access-site.\(site.id)")
    }
}
