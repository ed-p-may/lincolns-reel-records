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

    func testFocusRevisionAppliesOnceUntilRevisionAdvances() {
        XCTAssertTrue(
            CatchMapFilter.shouldApplyFocus(focusRevision: 1, handledFocusRevision: nil, hasFocusTarget: true)
        )
        XCTAssertFalse(
            CatchMapFilter.shouldApplyFocus(focusRevision: 1, handledFocusRevision: 1, hasFocusTarget: true)
        )
        XCTAssertTrue(
            CatchMapFilter.shouldApplyFocus(focusRevision: 2, handledFocusRevision: 1, hasFocusTarget: true)
        )
        XCTAssertFalse(
            CatchMapFilter.shouldApplyFocus(focusRevision: 2, handledFocusRevision: nil, hasFocusTarget: false)
        )
    }

    func testAllSpeciesChipDisambiguatesFromResetChip() {
        XCTAssertEqual(CatchMapFilter.resetChipTitle(availableSpecies: ["Bass", "Trout"]), "All")
        XCTAssertEqual(CatchMapFilter.resetChipTitle(availableSpecies: ["All", "Trout"]), "All species")
        XCTAssertEqual(CatchMapFilter.speciesChipIdentifier(for: "Rainbow Trout"), "map.species.Rainbow Trout")
        XCTAssertEqual(CatchMapFilter.speciesChipIdentifier(for: "All"), "map.species.option.All")
        XCTAssertEqual(CatchMapFilter.speciesChipIdentifier(for: "all"), "map.species.option.all")
    }

    func testFittingRegionFramesSingleAndMultiplePinnedCatches() throws {
        XCTAssertNil(CatchMapFilter.fittingRegion(for: []))

        let bass = catchItem(id: 1, species: "Bass", latitude: 42.31, longitude: -73.32)
        let single = try XCTUnwrap(CatchMapFilter.fittingRegion(for: [bass]))
        XCTAssertEqual(single.center.latitude, 42.31, accuracy: 0.0001)
        XCTAssertEqual(single.center.longitude, -73.32, accuracy: 0.0001)
        XCTAssertEqual(single.span.latitudeDelta, 0.035, accuracy: 0.0001)

        let trout = catchItem(id: 2, species: "Trout", latitude: 42.19, longitude: -73.35)
        let pair = try XCTUnwrap(CatchMapFilter.fittingRegion(for: [bass, trout]))
        XCTAssertEqual(pair.center.latitude, 42.25, accuracy: 0.0001)
        XCTAssertGreaterThan(pair.span.latitudeDelta, 0.12)
        XCTAssertLessThan(pair.span.latitudeDelta, 0.5)

        let eastOfDateLine = catchItem(id: 3, species: "Tuna", latitude: 10.0, longitude: 179.9)
        let westOfDateLine = catchItem(id: 4, species: "Tuna", latitude: 10.0, longitude: -179.9)
        let antimeridian = try XCTUnwrap(CatchMapFilter.fittingRegion(for: [eastOfDateLine, westOfDateLine]))
        XCTAssertLessThan(antimeridian.span.longitudeDelta, 1.0)
        XCTAssertGreaterThan(abs(antimeridian.center.longitude), 179.0)
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
