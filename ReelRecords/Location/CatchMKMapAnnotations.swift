import MapKit
import UIKit

enum MapMarkerStyler {
    @MainActor
    static func configureCatch(
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

    @MainActor
    static func configureAccess(
        _ view: MKMarkerAnnotationView,
        site: PublicAccessSite,
        isSelected: Bool
    ) {
        view.canShowCallout = false
        view.displayPriority = .required
        view.zPriority = isSelected ? .defaultSelected : .defaultUnselected
        view.titleVisibility = .adaptive
        view.markerTintColor = UIColor(isSelected ? ReelTheme.accessPin : ReelTheme.raisedSurface)
        view.glyphTintColor = UIColor(isSelected ? ReelTheme.page : ReelTheme.accessPin)
        view.glyphImage = UIImage(systemName: site.isBoatLaunch ? "sailboat.fill" : "figure.fishing")
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.accessibilityLabel = "\(site.name) public access"
        view.accessibilityIdentifier = "map.access-site.\(site.id)"
    }
}

final class CatchPinAnnotation: NSObject, MKAnnotation {
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

final class PublicAccessAnnotation: NSObject, MKAnnotation {
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
