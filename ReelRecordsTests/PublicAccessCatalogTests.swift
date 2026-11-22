@testable import LincolnReelRecords
import MapKit
import XCTest

final class PublicAccessCatalogTests: XCTestCase {
    func testBundledMassachusettsCatalogDecodesAllSitesWithValidCoordinates() {
        let catalog = PublicAccessCatalog.loadBundled(bundle: Bundle(for: BundleAnchor.self))
        let resolvedCatalog = catalog.sites.isEmpty ? PublicAccessCatalog.shared : catalog

        XCTAssertEqual(resolvedCatalog.sites.count, 282)
        XCTAssertTrue(resolvedCatalog.sites.allSatisfy { $0.coordinate != nil })
        XCTAssertTrue(resolvedCatalog.sites.allSatisfy { $0.state == "MA" })
        XCTAssertEqual(Set(resolvedCatalog.sites.map(\.id)).count, resolvedCatalog.sites.count)

        let lakeBuel = resolvedCatalog.sites.first { $0.name.localizedCaseInsensitiveContains("Lake Buel") }
        XCTAssertNotNil(lakeBuel)
        XCTAssertEqual(lakeBuel?.locationSubtitle, "Monterey, MA")
    }

    func testDecodedSiteMapsMultipleFacilityCodesAndCatalogHandlesDuplicateIDs() throws {
        let json = """
        {
          "source": "Test",
          "state": "MA",
          "fetchedAt": "2026-11-22",
          "sites": [
            {
              "id": "MA-10",
              "ofbaId": "10",
              "name": "Long Pond",
              "town": "Plymouth",
              "state": "MA",
              "facilityTypeCodes": ["a", "E", "A", "unknown"],
              "barrierFree": true,
              "latitude": 41.85,
              "longitude": -70.61
            },
            {
              "id": "MA-10",
              "ofbaId": "10",
              "name": "Duplicate Long Pond",
              "town": "Plymouth",
              "state": "MA",
              "facilityTypeCodes": ["F"],
              "barrierFree": false,
              "latitude": 41.85,
              "longitude": -70.61
            }
          ]
        }
        """
        let snapshot = try PublicAccessCatalog.decode(from: Data(json.utf8))
        let catalog = PublicAccessCatalog(source: snapshot.source, sites: snapshot.sites)
        let site = try XCTUnwrap(catalog.site(id: "MA-10"))
        XCTAssertEqual(site.name, "Long Pond")
        XCTAssertEqual(site.facilityTypes, [.generalAccess, .fishingPier])
        XCTAssertTrue(site.isBoatLaunch)
    }

    func testFacilityTypeCodeParsingHandlesCommaSeparatedAndDeduplicates() {
        XCTAssertEqual(
            PublicAccessFacilityType.parseCodes("A,E"),
            [.generalAccess, .fishingPier]
        )
        XCTAssertEqual(
            PublicAccessFacilityType.parseCodes(" b , f ; B , unknown "),
            [.fishermanAccess, .shoreFishing]
        )
        XCTAssertTrue(PublicAccessFacilityType.parseCodes(nil).isEmpty)
    }

    func testRegionLookupReturnsOnlySitesInsideBoundingBox() {
        let catalog = PublicAccessCatalog.shared
        let berkshires = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.25, longitude: -73.25),
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )
        let matches = catalog.sites(in: berkshires)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.name.localizedCaseInsensitiveContains("Lake Buel") })
        XCTAssertFalse(matches.contains { $0.town?.localizedCaseInsensitiveContains("Plymouth") == true })
    }

    func testMapSelectionIsMutuallyExclusiveBetweenCatchAndAccessSite() {
        let catchID = UUID()
        let catchSelection = CatchMapSelection.catchPin(catchID)
        XCTAssertEqual(catchSelection.catchID, catchID)
        XCTAssertNil(catchSelection.accessSiteID)

        let accessSelection = CatchMapSelection.accessSite("MA-1")
        XCTAssertEqual(accessSelection.accessSiteID, "MA-1")
        XCTAssertNil(accessSelection.catchID)
    }
}

private final class BundleAnchor {}
