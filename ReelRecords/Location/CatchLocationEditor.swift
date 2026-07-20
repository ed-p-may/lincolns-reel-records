import SwiftUI

struct CatchLocationEditor: View {
    @Environment(CatchLocationService.self) private var locationService
    @Binding var location: String
    @Binding var coordinate: CatchCoordinate?
    @Binding var isChoosingLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCATION")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(1)
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Named spot", text: $location)
                .textInputAutocapitalization(.words)
                .fieldInputStyle()
                .accessibilityIdentifier("add.location")
            pinEditor
        }
    }

    private var pinEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: coordinate == nil ? "mappin.slash" : "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(coordinate == nil ? ReelTheme.tertiaryText : ReelTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(coordinate == nil ? "No coordinate pin" : "Catch pin saved")
                        .font(ReelFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(ReelTheme.primaryText)
                    Text(statusMessage)
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
                Spacer()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { locationButtons }
                VStack(spacing: 10) { locationButtons }
            }
            if coordinate != nil {
                Button("Clear Pin", role: .destructive) {
                    coordinate = nil
                    locationService.reset()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("add.location.clear")
            }
        }
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
    }

    @ViewBuilder
    private var locationButtons: some View {
        Button {
            locationService.requestCurrentLocation()
        } label: {
            Label("Use Current", systemImage: "location.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(locationService.state == .requestingPermission || locationService.state == .locating)
        .accessibilityIdentifier("add.location.current")

        Button {
            isChoosingLocation = true
        } label: {
            Label("Choose on Map", systemImage: "map.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .accessibilityIdentifier("add.location.manual")
    }

    private var statusMessage: String {
        guard let coordinate else { return locationService.state.message }
        if case let .captured(captured, _) = locationService.state, captured == coordinate {
            return locationService.state.message
        }
        return coordinate.displayLabel
    }
}
