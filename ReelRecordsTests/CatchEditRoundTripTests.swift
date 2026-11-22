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

        // The Edit Catch form loads each number through `CatchFormatting.input` and reparses it on save.
        let saved = try repository.update(id: created.id, ownerID: ownerID, values: values(
            species: stored.species,
            weight: CatchFormatting.parseOptionalMeasurement(
                CatchFormatting.input(stored.weight), field: .weight, unchangedFrom: stored.weight
            ),
            length: CatchFormatting.parseOptionalMeasurement(
                CatchFormatting.input(stored.length), field: .length, unchangedFrom: stored.length
            ),
            conditions: CatchConditions(
                airTemperatureF: CatchFormatting.parseOptionalTemperature(
                    CatchFormatting.input(stored.conditions.airTemperatureF),
                    unchangedFrom: stored.conditions.airTemperatureF
                ),
                skyCondition: nil,
                waterTemperatureF: CatchFormatting.parseOptionalTemperature(
                    CatchFormatting.input(stored.conditions.waterTemperatureF),
                    unchangedFrom: stored.conditions.waterTemperatureF
                ),
                waterClarity: nil
            )
        ))

        XCTAssertEqual(saved.weight, 4.257)
        XCTAssertEqual(saved.length, 18.333)
        XCTAssertEqual(saved.values.conditions, precise)
        XCTAssertEqual(saved.syncState, .synced)
        XCTAssertEqual(try repository.pendingCount(ownerID: ownerID), 0)
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
