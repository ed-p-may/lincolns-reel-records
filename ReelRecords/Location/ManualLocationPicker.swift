import MapKit
import SwiftUI

struct ManualLocationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCoordinate: CatchCoordinate?
    @State private var cameraPosition: MapCameraPosition
    @State private var query = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var searchTask: Task<Void, Never>?

    let onUse: (CatchCoordinate) -> Void

    init(initialCoordinate: CatchCoordinate?, onUse: @escaping (CatchCoordinate) -> Void) {
        _selectedCoordinate = State(initialValue: initialCoordinate)
        let center = initialCoordinate?.mapCoordinate ?? CLLocationCoordinate2D(
            latitude: 42.3169,
            longitude: -73.3226
        )
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )))
        self.onUse = onUse
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if !searchResults.isEmpty {
                    searchResultList
                } else if let searchMessage {
                    Text(searchMessage)
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
                map
                footer
            }
            .background(ReelTheme.background)
            .navigationTitle("Choose Catch Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onDisappear { searchTask?.cancel() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ReelTheme.tertiaryText)
            TextField("Search lake, town, or address", text: $query)
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit { search() }
                .accessibilityIdentifier("manual-location.search")
            if isSearching {
                ProgressView()
            } else {
                Button("Search") { search() }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("manual-location.search-button")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 15))
        .padding(16)
    }

    private var searchResultList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                    Button {
                        select(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name ?? "Map result")
                                .font(ReelFont.body(.subheadline, weight: .semibold))
                                .lineLimit(1)
                            Text(item.placemark.title ?? "")
                                .font(ReelFont.body(.caption))
                                .foregroundStyle(ReelTheme.secondaryText)
                                .lineLimit(1)
                        }
                        .frame(width: 210, alignment: .leading)
                        .frame(minHeight: 58, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("manual-location.result.\(index)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let selectedCoordinate {
                    Annotation("Selected catch location", coordinate: selectedCoordinate.mapCoordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(ReelTheme.accent)
                            .background(.black.opacity(0.75), in: Circle())
                            .accessibilityIdentifier("manual-location.pin")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                guard let coordinate = proxy.convert(value.location, from: .local),
                      let selected = CatchCoordinate(
                          latitude: coordinate.latitude,
                          longitude: coordinate.longitude
                      )
                else { return }
                selectedCoordinate = selected
                searchMessage = nil
            })
            .accessibilityIdentifier("manual-location.map")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(selectedCoordinate?.displayLabel ?? "Tap the map to drop a pin.")
                .font(ReelFont.metadata(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
                .accessibilityIdentifier("manual-location.coordinate")
            PrimaryButton(title: "Use This Pin", systemImage: "mappin.and.ellipse") {
                guard let selectedCoordinate else { return }
                onUse(selectedCoordinate)
                dismiss()
            }
            .disabled(selectedCoordinate == nil)
            .accessibilityIdentifier("manual-location.use")
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        searchMessage = nil
        searchResults = []
        searchTask?.cancel()
        searchTask = Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = trimmed
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                searchResults = Array(response.mapItems.prefix(6))
                if searchResults.isEmpty {
                    searchMessage = "No places matched. You can still tap the map to place a pin."
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                searchMessage = "Place search is unavailable. You can still tap the map to place a pin."
            }
            isSearching = false
        }
    }

    private func select(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        guard let selected = CatchCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ) else { return }
        selectedCoordinate = selected
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        ))
    }
}

extension CatchCoordinate {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
