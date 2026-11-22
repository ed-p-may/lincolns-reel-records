@testable import LincolnReelRecords
import SwiftData
import XCTest

/// The Edit Catch form shows numbers at 2 decimals; saving without edits must not round stored values.
@MainActor
final class CatchEditRoundTripTests: XCTestCase {
    func testUneditedFormRoundTripKeepsPreciseValuesAndDoesNotQueueMutation() async throws {
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataCatchRepository(modelContext: container.mainContext)
        let ownerID = UUID()
        let remoteStore = InMemoryCatchRemoteStore()
        let coordinator = SyncCoordinator(repository: repository, remoteStore: remoteStore)
        let precise = CatchConditions(
            airTemperatureF: 61.875,
            skyCondition: nil,
            waterTemperatureF: 54.125,
            waterClarity: nil
        )
        let created = try repository.create(NewCatch(
            ownerID: ownerID,
            values: values(species: "Bass", weight: 4.257, length: 18.333, conditions: precise)
        ))
        await coordinator.sync(ownerID: ownerID)
        let stored = try XCTUnwrap(repository.item(id: created.id, ownerID: ownerID)).values

        let numbers = try CatchNumberInputs(loading: stored).parsed(unchangedFrom: stored)
        let saved = try repository.update(id: created.id, ownerID: ownerID, values: values(
            species: stored.species,
            weight: numbers.weight,
            length: numbers.length,
            conditions: CatchConditions(
                airTemperatureF: numbers.airTemperatureF,
                skyCondition: nil,
                waterTemperatureF: numbers.waterTemperatureF,
                waterClarity: nil
            )
        ))

        XCTAssertEqual(saved.weight, 4.257)
        XCTAssertEqual(saved.length, 18.333)
        XCTAssertEqual(saved.values.conditions, precise)
        XCTAssertEqual(saved.syncState, .synced)
        XCTAssertEqual(try repository.pendingCount(ownerID: ownerID), 0)
    }

    func testEditingOneNumberKeepsTheOthersExact() throws {
        let stored = values(
            species: "Bass",
            weight: 4.257,
            length: 18.333,
            conditions: CatchConditions(
                airTemperatureF: 61.875,
                skyCondition: nil,
                waterTemperatureF: 54.125,
                waterClarity: nil
            )
        )
        var form = CatchNumberInputs(loading: stored)
        form.weight = CatchFormatting.input(5.5)

        XCTAssertEqual(
            try form.parsed(unchangedFrom: stored),
            CatchNumberInputs.Parsed(weight: 5.5, length: 18.333, airTemperatureF: 61.875, waterTemperatureF: 54.125)
        )
    }

    private func values(
        species: String,
        weight: Double?,
        length: Double?,
        conditions: CatchConditions
    ) -> CatchValues {
        CatchValues(
            species: species,
            weight: weight,
            length: length,
            caughtAt: Date(timeIntervalSince1970: 1_700_000_000),
            location: nil,
            coordinate: nil,
            conditions: conditions,
            lureText: nil,
            rodReel: nil,
            notes: nil,
            released: true,
            bookmarked: false
        )
    }
}
