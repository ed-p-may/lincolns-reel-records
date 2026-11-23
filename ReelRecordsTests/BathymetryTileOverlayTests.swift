@testable import LincolnReelRecords
import MapKit
import os
import SwiftUI
import XCTest

final class BathymetryTileOverlayTests: XCTestCase {
    override func tearDown() {
        StubTileURLProtocol.reset()
        super.tearDown()
    }

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

    func testOutOfBoundsTileShortCircuitsWithoutSendingNetworkRequest() {
        StubTileURLProtocol.setResponse(.status(200, Data([1, 2, 3])))
        let overlay = MassGISBathymetryTileOverlay(session: makeStubSession())
        let nycPath = MKTileOverlayPath(x: 4824, y: 6160, z: 14, contentScaleFactor: 1)
        let expectation = expectation(description: "Out-of-bounds tile short-circuits")

        overlay.loadTile(at: nycPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, MassGISBathymetryTileOverlay.emptyTilePNG)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 0)
        XCTAssertFalse(overlay.consumeTransientFailure())
    }

    func testInBoundsTileReturnsPayloadOnHTTP200() {
        let payload = Data([0x89, 0x50, 0x4E, 0x47, 0xAA, 0xBB])
        StubTileURLProtocol.setResponse(.status(200, payload))
        let overlay = MassGISBathymetryTileOverlay(session: makeStubSession())
        let lakeBuelPath = MKTileOverlayPath(x: 4856, y: 6071, z: 14, contentScaleFactor: 1)
        let expectation = expectation(description: "In-bounds HTTP 200 tile loads")

        overlay.loadTile(at: lakeBuelPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, payload)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 1)
        XCTAssertFalse(overlay.consumeTransientFailure())
    }

    func testInBoundsTileReturnsEmptyPNGOnHTTP404WithoutTransientFailure() {
        StubTileURLProtocol.setResponse(.status(404, Data()))
        let overlay = MassGISBathymetryTileOverlay(session: makeStubSession())
        let lakeBuelPath = MKTileOverlayPath(x: 4856, y: 6071, z: 14, contentScaleFactor: 1)
        let expectation = expectation(description: "In-bounds HTTP 404 degrades silently")

        overlay.loadTile(at: lakeBuelPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, MassGISBathymetryTileOverlay.emptyTilePNG)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 1)
        XCTAssertFalse(overlay.consumeTransientFailure())
    }

    func testInBoundsOfflineFailureReturnsEmptyPNGAndFlagsTransientRetry() {
        StubTileURLProtocol.setResponse(.error(URLError(.notConnectedToInternet)))
        let overlay = MassGISBathymetryTileOverlay(session: makeStubSession())
        let lakeBuelPath = MKTileOverlayPath(x: 4856, y: 6071, z: 14, contentScaleFactor: 1)
        let expectation = expectation(description: "Offline error degrades silently")

        overlay.loadTile(at: lakeBuelPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, MassGISBathymetryTileOverlay.emptyTilePNG)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 1)
        XCTAssertTrue(overlay.consumeTransientFailure())
        XCTAssertFalse(overlay.consumeTransientFailure())
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

    func testCachedTileIsServedFromCacheWhenOffline() {
        let payload = Data([0x89, 0x50, 0x4E, 0x47, 0x11, 0x22, 0x33])
        StubTileURLProtocol.setResponse(.cacheable200(payload))
        let session = makeCachingStubSession()
        let overlay = MassGISBathymetryTileOverlay(session: session)
        let lakeBuelPath = MKTileOverlayPath(x: 4856, y: 6071, z: 14, contentScaleFactor: 1)

        let firstLoad = expectation(description: "Initial online tile load populates cache")
        overlay.loadTile(at: lakeBuelPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, payload)
            firstLoad.fulfill()
        }
        wait(for: [firstLoad], timeout: 2.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 1)

        StubTileURLProtocol.setResponse(.error(URLError(.notConnectedToInternet)))
        let offlineLoad = expectation(description: "Cached tile served while offline")
        overlay.loadTile(at: lakeBuelPath) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, payload)
            offlineLoad.fulfill()
        }
        wait(for: [offlineLoad], timeout: 2.0)
        XCTAssertEqual(StubTileURLProtocol.requestCount, 0)
        XCTAssertFalse(overlay.consumeTransientFailure())
    }

    @MainActor
    func testBridgeAttachesAndRemovesBathymetryOverlayWithoutResettingCameraOrSelection() {
        let catchItem = makeTestCatch()
        var selection: CatchMapSelection? = .catchPin(catchItem.id)
        let selectionBinding = Binding(get: { selection }, set: { selection = $0 })
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.175, longitude: -73.279),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        let initialBridge = CatchMKMapView(
            catches: [catchItem],
            accessSites: [],
            showPublicAccess: false,
            showLakeDepths: false,
            mapStyle: .standard,
            targetRegion: initialRegion,
            cameraRevision: 1,
            selection: selectionBinding
        )
        let coordinator = initialBridge.makeCoordinator()
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        CatchMKMapView.configureMapView(mapView, coordinator: coordinator, style: .standard)
        initialBridge.applyUpdate(to: mapView, coordinator: coordinator)

        let pannedRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.20, longitude: -73.30),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(pannedRegion, animated: false)
        let centerBefore = mapView.region.center

        let depthsOnBridge = CatchMKMapView(
            catches: [catchItem],
            accessSites: [],
            showPublicAccess: false,
            showLakeDepths: true,
            mapStyle: .standard,
            targetRegion: initialRegion,
            cameraRevision: 1,
            selection: selectionBinding
        )
        depthsOnBridge.applyUpdate(to: mapView, coordinator: coordinator)
        XCTAssertTrue(mapView.overlays.contains { $0 is MassGISBathymetryTileOverlay })
        XCTAssertEqual(mapView.region.center.latitude, centerBefore.latitude, accuracy: 0.001)
        XCTAssertEqual(mapView.region.center.longitude, centerBefore.longitude, accuracy: 0.001)
        XCTAssertEqual(mapView.selectedAnnotations.count, 1)

        initialBridge.applyUpdate(to: mapView, coordinator: coordinator)
        XCTAssertFalse(mapView.overlays.contains { $0 is MassGISBathymetryTileOverlay })
        XCTAssertEqual(mapView.region.center.latitude, centerBefore.latitude, accuracy: 0.001)
        XCTAssertEqual(mapView.selectedAnnotations.count, 1)
    }

    private func makeTestCatch() -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: UUID(),
            values: CatchValues(
                species: "Rainbow Trout",
                weight: nil,
                length: nil,
                caughtAt: Date(timeIntervalSince1970: 1_752_000_000),
                location: "Lake Buel",
                coordinate: CatchCoordinate(latitude: 42.175, longitude: -73.279),
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: Date(timeIntervalSince1970: 1_752_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_752_000_000),
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }

    private func makeStubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubTileURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeCachingStubSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 0)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.protocolClasses = [StubTileURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class StubTileURLProtocol: URLProtocol, @unchecked Sendable {
    enum StubResponse: Sendable {
        case status(Int, Data)
        case cacheable200(Data)
        case error(URLError)
    }

    private struct State: Sendable {
        var response: StubResponse = .status(404, Data())
        var requestCount = 0
    }

    private static let stateLock = OSAllocatedUnfairLock(initialState: State())

    static var requestCount: Int {
        stateLock.withLock(\.requestCount)
    }

    static func setResponse(_ response: StubResponse) {
        stateLock.withLock {
            $0.response = response
            $0.requestCount = 0
        }
    }

    static func reset() {
        stateLock.withLock {
            $0.response = .status(404, Data())
            $0.requestCount = 0
        }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let stub = Self.stateLock.withLock { state -> StubResponse in
            state.requestCount += 1
            return state.response
        }
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        switch stub {
        case let .status(code, data):
            let response = HTTPURLResponse(
                url: url,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .cacheable200(data):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Cache-Control": "public, max-age=3600"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .error(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
