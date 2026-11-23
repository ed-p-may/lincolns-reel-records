@testable import LincolnReelRecords
import MapKit
import XCTest

final class BathymetryTileOverlayTests: XCTestCase {
    func testTileURLUsesArcGISZYXOrder() {
        let overlay = MassGISBathymetryTileOverlay()
        let path = MKTileOverlayPath(x: 4856, y: 6071, z: 14, contentScaleFactor: 2)

        XCTAssertEqual(
            overlay.url(forTilePath: path).absoluteString,
            "https://tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/arcgis/rest/services/"
                + "Inland_Bathymetry/MapServer/tile/14/6071/4856"
        )
    }

    func testMassachusettsBoundingBoxAndZoomGating() {
        // Lake Buel, MA at zoom 14 (verified live tile 14/6071/4856)
        XCTAssertTrue(MassGISBathymetryTileOverlay.shouldFetchTile(column: 4856, row: 6071, zoom: 14))
        // Same coordinates at zoom 10 (below minZoom = 11)
        XCTAssertFalse(MassGISBathymetryTileOverlay.shouldFetchTile(column: 303, row: 379, zoom: 10))
        // Above maxZoom = 18
        XCTAssertFalse(MassGISBathymetryTileOverlay.shouldFetchTile(column: 155_392, row: 194_272, zoom: 19))
        // Negative indices
        XCTAssertFalse(MassGISBathymetryTileOverlay.shouldFetchTile(column: -1, row: 6071, zoom: 14))
        // New York City tile at zoom 14 (40.7128, -74.0060 -> x=4824, y=6160)
        XCTAssertFalse(MassGISBathymetryTileOverlay.shouldFetchTile(column: 4824, row: 6160, zoom: 14))
        // Mid-Atlantic Ocean at zoom 14
        XCTAssertFalse(MassGISBathymetryTileOverlay.shouldFetchTile(column: 6000, row: 6071, zoom: 14))
    }

    func testOutOfBoundsTileShortCircuitsToEmptyPNGWithoutNetwork() {
        let overlay = MassGISBathymetryTileOverlay()
        let nycPath = MKTileOverlayPath(x: 4824, y: 6160, z: 14, contentScaleFactor: 1)
        let expectation = expectation(description: "Out-of-bounds tile short-circuits")

        overlay.loadTile(at: nycPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, MassGISBathymetryTileOverlay.emptyTilePNG)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testOverlayAlphaAndConfigurationDefaults() {
        let overlay = MassGISBathymetryTileOverlay()
        XCTAssertFalse(overlay.canReplaceMapContent)
        XCTAssertEqual(overlay.minimumZ, 11)
        XCTAssertEqual(overlay.maximumZ, 18)
        XCTAssertEqual(MassGISBathymetryTileOverlay.overlayAlpha(for: .standard), 0.78, accuracy: 0.001)
        XCTAssertEqual(MassGISBathymetryTileOverlay.overlayAlpha(for: .hybrid), 0.68, accuracy: 0.001)
        XCTAssertEqual(MassGISBathymetryTileOverlay.overlayAlpha(for: .satellite), 0.68, accuracy: 0.001)
    }
}
