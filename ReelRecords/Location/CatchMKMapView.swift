import MapKit
import Network
import SwiftUI
import UIKit

struct CatchMKMapView: UIViewRepresentable {
    let catches: [CatchItem]
    let accessSites: [PublicAccessSite]
    let showPublicAccess: Bool
    let showLakeDepths: Bool
    let mapStyle: CatchMapStyle
    let targetRegion: MKCoordinateRegion?
    let cameraRevision: Int
    @Binding var selection: CatchMapSelection?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        Self.configureMapView(mapView, coordinator: context.coordinator, style: mapStyle)
        return mapView
    }

    static func configureMapView(
        _ mapView: MKMapView,
        coordinator: Coordinator,
        style: CatchMapStyle
    ) {
        mapView.delegate = coordinator
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = false
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.catchReuseID
        )
        mapView.register(
            MKAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: Coordinator.accessReuseID
        )
        applyConfiguration(to: mapView, style: style)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if coordinator.lastAppliedStyle != mapStyle {
            coordinator.lastAppliedStyle = mapStyle
            Self.applyConfiguration(to: mapView, style: mapStyle)
            coordinator.updateBathymetryAlpha(on: mapView, style: mapStyle)
        }

        coordinator.syncBathymetryOverlay(on: mapView, isVisible: showLakeDepths)
        coordinator.syncCatchAnnotations(on: mapView, catches: catches)
        coordinator.syncAccessAnnotations(
            on: mapView,
            sites: showPublicAccess ? accessSites : []
        )

        if cameraRevision != coordinator.lastAppliedCameraRevision, let targetRegion {
            let animated = coordinator.lastAppliedCameraRevision != nil
            coordinator.lastAppliedCameraRevision = cameraRevision
            mapView.setRegion(targetRegion, animated: animated)
        }

        coordinator.syncSelection(on: mapView, selection: selection)
    }

    private static func applyConfiguration(to mapView: MKMapView, style: CatchMapStyle) {
        switch style {
        case .standard:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            config.pointOfInterestFilter = .excludingAll
            mapView.preferredConfiguration = config
        case .hybrid:
            let config = MKHybridMapConfiguration(elevationStyle: .flat)
            config.pointOfInterestFilter = .excludingAll
            mapView.preferredConfiguration = config
        case .satellite:
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
        }
    }
}

extension CatchMKMapView {
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        static let catchReuseID = "CatchPinAnnotationView"
        static let accessReuseID = "PublicAccessAnnotationView"

        var parent: CatchMKMapView
        var lastAppliedStyle: CatchMapStyle?
        var lastAppliedCameraRevision: Int?

        private let bathymetryOverlay = MassGISBathymetryTileOverlay()
        private var bathymetryAttached = false
        private var pathMonitor: NWPathMonitor?
        private weak var monitoredMapView: MKMapView?
        private var catchAnnotationsByID: [UUID: CatchPinAnnotation] = [:]
        private var accessAnnotationsByID: [String: PublicAccessAnnotation] = [:]
        private var pendingSelection: CatchMapSelection?
        private var isSyncingSelection = false

        init(parent: CatchMKMapView) {
            self.parent = parent
        }

        deinit {
            pathMonitor?.cancel()
        }

        func syncBathymetryOverlay(on mapView: MKMapView, isVisible: Bool) {
            if isVisible, !bathymetryAttached {
                bathymetryAttached = true
                mapView.addOverlay(bathymetryOverlay, level: .aboveRoads)
                startPathMonitoring(for: mapView)
            } else if !isVisible, bathymetryAttached {
                bathymetryAttached = false
                stopPathMonitoring()
                mapView.removeOverlay(bathymetryOverlay)
            }
        }

        private func startPathMonitoring(for mapView: MKMapView) {
            guard pathMonitor == nil else { return }
            monitoredMapView = mapView
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                guard path.status == .satisfied else { return }
                Task { @MainActor [weak self] in
                    self?.reloadBathymetryIfNeeded()
                }
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            pathMonitor = monitor
        }

        private func stopPathMonitoring() {
            pathMonitor?.cancel()
            pathMonitor = nil
            monitoredMapView = nil
        }

        private func reloadBathymetryIfNeeded() {
            guard bathymetryAttached,
                  bathymetryOverlay.consumeTransientFailure(),
                  let mapView = monitoredMapView,
                  let renderer = mapView.renderer(for: bathymetryOverlay) as? MKTileOverlayRenderer
            else {
                return
            }
            renderer.reloadData()
        }

        func updateBathymetryAlpha(on mapView: MKMapView, style: CatchMapStyle) {
            guard bathymetryAttached,
                  let renderer = mapView.renderer(for: bathymetryOverlay) as? MKTileOverlayRenderer
            else {
                return
            }
            renderer.alpha = MassGISBathymetryTileOverlay.overlayAlpha(for: style)
        }

        func syncCatchAnnotations(on mapView: MKMapView, catches: [CatchItem]) {
            let desiredByID = Dictionary(
                uniqueKeysWithValues: catches.compactMap { item -> (UUID, CatchItem)? in
                    item.coordinate == nil ? nil : (item.id, item)
                }
            )

            var toRemove: [MKAnnotation] = []
            for (id, existing) in catchAnnotationsByID {
                guard let updated = desiredByID[id], let coord = updated.coordinate else {
                    toRemove.append(existing)
                    catchAnnotationsByID.removeValue(forKey: id)
                    continue
                }
                let coordinateChanged = existing.coordinate.latitude != coord.latitude
                    || existing.coordinate.longitude != coord.longitude
                let metadataChanged = existing.catchItem.species != updated.species
                    || existing.catchItem.location != updated.location
                if coordinateChanged || metadataChanged {
                    toRemove.append(existing)
                    catchAnnotationsByID.removeValue(forKey: id)
                }
            }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            var toAdd: [MKAnnotation] = []
            for item in catches where item.coordinate != nil {
                guard catchAnnotationsByID[item.id] == nil else { continue }
                let annotation = CatchPinAnnotation(catchItem: item)
                catchAnnotationsByID[item.id] = annotation
                toAdd.append(annotation)
            }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }
        }

        func syncAccessAnnotations(on mapView: MKMapView, sites: [PublicAccessSite]) {
            if sites.isEmpty {
                if !accessAnnotationsByID.isEmpty {
                    mapView.removeAnnotations(Array(accessAnnotationsByID.values))
                    accessAnnotationsByID.removeAll()
                }
                return
            }

            let desiredIDs = Set(sites.map(\.id))
            var toRemove: [MKAnnotation] = []
            for (id, existing) in accessAnnotationsByID where !desiredIDs.contains(id) {
                toRemove.append(existing)
                accessAnnotationsByID.removeValue(forKey: id)
            }
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            var toAdd: [MKAnnotation] = []
            for site in sites where accessAnnotationsByID[site.id] == nil {
                let annotation = PublicAccessAnnotation(site: site)
                accessAnnotationsByID[site.id] = annotation
                toAdd.append(annotation)
            }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }
        }

        func syncSelection(on mapView: MKMapView, selection: CatchMapSelection?) {
            let targetAnnotation: (any MKAnnotation)? = switch selection {
            case let .catchPin(id):
                catchAnnotationsByID[id]
            case let .accessSite(id):
                accessAnnotationsByID[id]
            case nil:
                nil
            }

            let currentSelected = mapView.selectedAnnotations.first
            if let targetAnnotation, currentSelected === targetAnnotation {
                pendingSelection = nil
                refreshAppearance(for: targetAnnotation, on: mapView, isSelected: true)
                return
            }

            isSyncingSelection = true
            defer { isSyncingSelection = false }

            for existing in mapView.selectedAnnotations {
                mapView.deselectAnnotation(existing, animated: false)
                refreshAppearance(for: existing, on: mapView, isSelected: false)
            }
            if let targetAnnotation {
                mapView.selectAnnotation(targetAnnotation, animated: false)
                refreshAppearance(for: targetAnnotation, on: mapView, isSelected: true)
                let didSelect = mapView.selectedAnnotations.contains { $0 === targetAnnotation }
                pendingSelection = didSelect ? nil : selection
            } else {
                pendingSelection = nil
            }
        }

        func mapView(_ mapView: MKMapView, didAdd _: [MKAnnotationView]) {
            retryPendingSelectionIfNeeded(on: mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated _: Bool) {
            retryPendingSelectionIfNeeded(on: mapView)
        }

        private func retryPendingSelectionIfNeeded(on mapView: MKMapView) {
            guard let pending = pendingSelection, pending == parent.selection else {
                pendingSelection = nil
                return
            }
            syncSelection(on: mapView, selection: pending)
        }

        func mapView(_: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MassGISBathymetryTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = MassGISBathymetryTileOverlay.overlayAlpha(for: parent.mapStyle)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if let catchAnnotation = annotation as? CatchPinAnnotation {
                let view = (mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.catchReuseID,
                    for: catchAnnotation
                ) as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(
                    annotation: catchAnnotation,
                    reuseIdentifier: Self.catchReuseID
                )
                let isSelected = parent.selection == .catchPin(catchAnnotation.catchItem.id)
                configureCatchView(view, catchItem: catchAnnotation.catchItem, isSelected: isSelected)
                return view
            }

            if let accessAnnotation = annotation as? PublicAccessAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Self.accessReuseID,
                    for: accessAnnotation
                )
                let isSelected = parent.selection == .accessSite(accessAnnotation.site.id)
                configureAccessView(view, site: accessAnnotation.site, isSelected: isSelected)
                return view
            }

            return nil
        }

        func mapView(_: MKMapView, didSelect view: MKAnnotationView) {
            guard !isSyncingSelection, let annotation = view.annotation else { return }
            if let catchAnnotation = annotation as? CatchPinAnnotation {
                parent.selection = .catchPin(catchAnnotation.catchItem.id)
                if let markerView = view as? MKMarkerAnnotationView {
                    configureCatchView(markerView, catchItem: catchAnnotation.catchItem, isSelected: true)
                }
            } else if let accessAnnotation = annotation as? PublicAccessAnnotation {
                parent.selection = .accessSite(accessAnnotation.site.id)
                configureAccessView(view, site: accessAnnotation.site, isSelected: true)
            }
        }

        func mapView(_: MKMapView, didDeselect view: MKAnnotationView) {
            guard !isSyncingSelection, let annotation = view.annotation else { return }
            if let catchAnnotation = annotation as? CatchPinAnnotation {
                if let markerView = view as? MKMarkerAnnotationView {
                    configureCatchView(markerView, catchItem: catchAnnotation.catchItem, isSelected: false)
                }
                if parent.selection == .catchPin(catchAnnotation.catchItem.id) {
                    parent.selection = nil
                }
            } else if let accessAnnotation = annotation as? PublicAccessAnnotation {
                configureAccessView(view, site: accessAnnotation.site, isSelected: false)
                if parent.selection == .accessSite(accessAnnotation.site.id) {
                    parent.selection = nil
                }
            }
        }

        private func refreshAppearance(
            for annotation: any MKAnnotation,
            on mapView: MKMapView,
            isSelected: Bool
        ) {
            guard let view = mapView.view(for: annotation) else { return }
            if let catchAnnotation = annotation as? CatchPinAnnotation {
                if let markerView = view as? MKMarkerAnnotationView {
                    configureCatchView(markerView, catchItem: catchAnnotation.catchItem, isSelected: isSelected)
                }
            } else if let accessAnnotation = annotation as? PublicAccessAnnotation {
                configureAccessView(view, site: accessAnnotation.site, isSelected: isSelected)
            }
        }

        private func configureCatchView(
            _ view: MKMarkerAnnotationView,
            catchItem: CatchItem,
            isSelected: Bool
        ) {
            view.canShowCallout = false
            view.displayPriority = .required
            view.zPriority = .max
            view.titleVisibility = .adaptive
            view.markerTintColor = UIColor(isSelected ? ReelTheme.accentHighlight : ReelTheme.accent)
            view.glyphImage = UIImage(systemName: isSelected ? "fish.circle.fill" : "fish.fill")
            view.isAccessibilityElement = true
            view.accessibilityLabel = catchItem.species
            view.accessibilityIdentifier = "map.catch-pin.\(catchItem.id.uuidString)"
        }

        private func configureAccessView(
            _ view: MKAnnotationView,
            site: PublicAccessSite,
            isSelected: Bool
        ) {
            view.canShowCallout = false
            view.displayPriority = .required
            view.zPriority = isSelected ? .defaultSelected : .defaultUnselected
            view.image = AccessPinRenderer.image(isBoatLaunch: site.isBoatLaunch, isSelected: isSelected)
            view.centerOffset = .zero
            view.isAccessibilityElement = true
            view.accessibilityTraits = .button
            view.accessibilityLabel = "\(site.name) public access"
            view.accessibilityIdentifier = "map.access-site.\(site.id)"
        }
    }
}

private enum AccessPinRenderer {
    static func image(isBoatLaunch: Bool, isSelected: Bool) -> UIImage {
        let diameter: CGFloat = isSelected ? 30 : 24
        let size = CGSize(width: diameter + 4, height: diameter + 4)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let circleRect = CGRect(x: 2, y: 2, width: diameter, height: diameter)
            let fillColor = isSelected
                ? UIColor(ReelTheme.accessPin)
                : UIColor(ReelTheme.surface).withAlphaComponent(0.92)
            let strokeColor = UIColor(ReelTheme.accessPin)
            let path = UIBezierPath(ovalIn: circleRect)
            fillColor.setFill()
            path.fill()
            strokeColor.setStroke()
            path.lineWidth = isSelected ? 2 : 1.5
            path.stroke()

            let symbolName = isBoatLaunch ? "sailboat.fill" : "figure.fishing"
            let symbolConfig = UIImage.SymbolConfiguration(
                pointSize: isSelected ? 13 : 11,
                weight: .semibold
            )
            let tint = isSelected ? UIColor(ReelTheme.page) : UIColor(ReelTheme.primaryText)
            let symbol = UIImage(systemName: symbolName, withConfiguration: symbolConfig)?
                .withTintColor(tint, renderingMode: .alwaysOriginal)
            if let symbol {
                let symbolRect = CGRect(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2,
                    width: symbol.size.width,
                    height: symbol.size.height
                )
                symbol.draw(in: symbolRect)
            }
        }
    }
}

private final class CatchPinAnnotation: NSObject, MKAnnotation {
    let catchItem: CatchItem
    let coordinate: CLLocationCoordinate2D
    var title: String? {
        catchItem.species
    }

    var subtitle: String? {
        catchItem.location
    }

    init(catchItem: CatchItem) {
        self.catchItem = catchItem
        coordinate = catchItem.coordinate?.mapCoordinate ?? kCLLocationCoordinate2DInvalid
    }
}

private final class PublicAccessAnnotation: NSObject, MKAnnotation {
    let site: PublicAccessSite
    let coordinate: CLLocationCoordinate2D
    var title: String? {
        site.name
    }

    var subtitle: String? {
        site.locationSubtitle
    }

    init(site: PublicAccessSite) {
        self.site = site
        coordinate = site.mapCoordinate
    }
}
