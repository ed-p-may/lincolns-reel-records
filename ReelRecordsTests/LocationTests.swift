import CoreLocation
@testable import LincolnReelRecords
import XCTest

final class LocationTests: XCTestCase {
    func testCoordinateValidationAcceptsBoundsAndRejectsInvalidValues() {
        XCTAssertNotNil(CatchCoordinate(latitude: -90, longitude: 180))
        XCTAssertNotNil(CatchCoordinate(latitude: 90, longitude: -180))
        XCTAssertNil(CatchCoordinate(latitude: 90.0001, longitude: 0))
        XCTAssertNil(CatchCoordinate(latitude: 0, longitude: -180.0001))
        XCTAssertNil(CatchCoordinate(latitude: .nan, longitude: 0))
        XCTAssertNil(CatchCoordinate(latitude: 0, longitude: .infinity))
        XCTAssertNil(CatchCoordinate(latitude: 42, longitude: nil))
        XCTAssertNil(CatchCoordinate(latitude: nil, longitude: -73))
        XCTAssertEqual(
            CatchCoordinate(latitude: 42.3169, longitude: -73.3226)?.displayLabel,
            "42.31690, -73.32260"
        )
    }

    func testFixPolicyRejectsInvalidInaccurateAndStaleSamples() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinate = try XCTUnwrap(CatchCoordinate(latitude: 42.3169, longitude: -73.3226))

        XCTAssertNil(LocationFixPolicy.rejection(for: LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: 24,
            timestamp: now.addingTimeInterval(-30)
        ), now: now))
        XCTAssertEqual(LocationFixPolicy.rejection(for: LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: -1,
            timestamp: now
        ), now: now), .invalidAccuracy)
        XCTAssertEqual(LocationFixPolicy.rejection(for: LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: 101,
            timestamp: now
        ), now: now), .inaccurate)
        XCTAssertEqual(LocationFixPolicy.rejection(for: LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: 20,
            timestamp: now.addingTimeInterval(-121)
        ), now: now), .stale)
    }

    func testSpotCountUsesTrimmedCaseInsensitiveExactNames() {
        let catches = [
            catchItem(location: " Stockbridge Bowl "),
            catchItem(location: "stockbridge bowl"),
            catchItem(location: "Stockbridge Bowl North"),
            catchItem(location: "  "),
            catchItem(location: nil)
        ]

        XCTAssertEqual(SpotSummary.uniqueCount(in: catches), 2)
    }

    func testAuthorizationAvailabilityCoversEveryForegroundState() {
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .notDetermined,
            servicesEnabled: true
        ), .notDetermined)
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .authorizedWhenInUse,
            servicesEnabled: true
        ), .allowed)
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .authorizedAlways,
            servicesEnabled: true
        ), .allowed)
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .denied,
            servicesEnabled: true
        ), .denied)
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .restricted,
            servicesEnabled: true
        ), .restricted)
        XCTAssertEqual(LocationAuthorizationAvailability.resolve(
            authorizationStatus: .authorizedWhenInUse,
            servicesEnabled: false
        ), .servicesDisabled)
    }

    private func catchItem(location: String?) -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: UUID(),
            values: CatchValues(
                species: "Perch",
                weight: nil,
                length: nil,
                caughtAt: .now,
                location: location,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }
}
