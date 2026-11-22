@testable import LincolnReelRecords
import XCTest

final class CatchMapTests: XCTestCase {
    func testPinnedCatchesExcludesUnpinnedAndFiltersSpeciesInsensitively() {
        let bass = catchItem(id: 1, species: "Largemouth Bass", latitude: 42.31, longitude: -73.32)
        let trout = catchItem(id: 2, species: "Café Trout", latitude: 42.19, longitude: -73.35)
        let unpinned = catchItem(id: 3, species: "Largemouth Bass", latitude: nil, longitude: nil)

        let allPinned = CatchDiscovery.pinnedCatches([bass, trout, unpinned])
        XCTAssertEqual(allPinned.map(\.id), [bass.id, trout.id])

        let filteredBass = CatchDiscovery.pinnedCatches([bass, trout, unpinned], species: "largemouth bass")
        XCTAssertEqual(filteredBass.map(\.id), [bass.id])

        let filteredTrout = CatchDiscovery.pinnedCatches([bass, trout, unpinned], species: "cafe trout")
        XCTAssertEqual(filteredTrout.map(\.id), [trout.id])
    }

    func testReconciledSpeciesResetsWhenRemovedOrSingleSpeciesRemains() {
        XCTAssertEqual(
            CatchMapFilter.reconciledSpecies("rainbow trout", availableSpecies: ["Bass", "Rainbow Trout"]),
            "Rainbow Trout"
        )
        XCTAssertNil(
            CatchMapFilter.reconciledSpecies("Walleye", availableSpecies: ["Bass", "Rainbow Trout"])
        )
        XCTAssertNil(
            CatchMapFilter.reconciledSpecies("Bass", availableSpecies: ["Bass"])
        )
    }

    func testReconciledSelectionPreservesVisiblePinAndFallsBackToFirst() {
        let bass = catchItem(id: 1, species: "Bass", latitude: 42.31, longitude: -73.32)
        let trout = catchItem(id: 2, species: "Rainbow Trout", latitude: 42.19, longitude: -73.35)

        XCTAssertEqual(
            CatchMapFilter.reconciledSelection(trout.id, in: [bass, trout]),
            trout.id
        )
        XCTAssertEqual(
            CatchMapFilter.reconciledSelection(bass.id, in: [trout]),
            trout.id
        )
        XCTAssertNil(CatchMapFilter.reconciledSelection(bass.id, in: []))
    }

    func testSpeciesForFocusClearsIncompatibleFilterOnly() {
        let bass = catchItem(id: 1, species: "Largemouth Bass", latitude: 42.31, longitude: -73.32)
        let trout = catchItem(id: 2, species: "Rainbow Trout", latitude: 42.19, longitude: -73.35)

        XCTAssertNil(
            CatchMapFilter.speciesForFocus(
                catchID: trout.id,
                selectedSpecies: "Largemouth Bass",
                in: [bass, trout]
            )
        )
        XCTAssertEqual(
            CatchMapFilter.speciesForFocus(
                catchID: bass.id,
                selectedSpecies: "largemouth bass",
                in: [bass, trout]
            ),
            "largemouth bass"
        )
    }

    func testCountSummaryFormatsFilteredAndUnfilteredCounts() {
        XCTAssertEqual(
            CatchMapFilter.countSummary(filteredCount: 2, totalCount: 2, spotCount: 2, isFiltered: false),
            "2 CATCHES ACROSS 2 SPOTS"
        )
        XCTAssertEqual(
            CatchMapFilter.countSummary(filteredCount: 1, totalCount: 1, spotCount: 1, isFiltered: false),
            "1 CATCH ACROSS 1 SPOT"
        )
        XCTAssertEqual(
            CatchMapFilter.countSummary(filteredCount: 1, totalCount: 2, spotCount: 1, isFiltered: true),
            "1 OF 2 CATCHES ACROSS 1 SPOT"
        )
    }

    func testCatchMapStyleStorageAndTitles() {
        XCTAssertEqual(CatchMapStyle.storageKey, "reelrecords.map.style")
        XCTAssertEqual(CatchMapStyle.allCases.map(\.title), ["Standard", "Hybrid", "Satellite"])
        XCTAssertEqual(CatchMapStyle(rawValue: "hybrid"), .hybrid)
    }

    private func catchItem(
        id: Int,
        species: String,
        latitude: Double?,
        longitude: Double?
    ) -> CatchItem {
        CatchItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            ownerID: UUID(),
            values: CatchValues(
                species: species,
                weight: nil,
                length: nil,
                caughtAt: Date(timeIntervalSince1970: TimeInterval(id)),
                location: "Lake \(id)",
                coordinate: CatchCoordinate(latitude: latitude, longitude: longitude),
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id)),
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }
}
