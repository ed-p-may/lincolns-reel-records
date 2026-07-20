@testable import LincolnReelRecords
import SwiftData
import XCTest

@MainActor
final class CatchRepositoryTests: XCTestCase {
    func testCreateNormalizesAndPersistsAllScalarFields() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let caughtAt = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinate = try XCTUnwrap(CatchCoordinate(latitude: 42.3169, longitude: -73.3226))

        let created = try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(
                species: "  Smallmouth Bass  ",
                weight: 3.25,
                length: 18.5,
                caughtAt: caughtAt,
                location: "  Stockbridge Bowl ",
                coordinate: coordinate,
                conditions: CatchConditions(
                    airTemperatureF: 72.5,
                    skyCondition: .partlyCloudy,
                    waterTemperatureF: 66,
                    waterClarity: .stained
                ),
                lureText: "  Green pumpkin jig ",
                rodReel: "  7-foot medium / spinning ",
                notes: "  Wind picked up after noon. ",
                released: false
            )
        ))

        XCTAssertEqual(created.species, "Smallmouth Bass")
        XCTAssertEqual(created.weight, 3.25)
        XCTAssertEqual(created.length, 18.5)
        XCTAssertEqual(created.caughtAt, caughtAt)
        XCTAssertEqual(created.location, "Stockbridge Bowl")
        XCTAssertEqual(created.coordinate, coordinate)
        XCTAssertEqual(created.conditions.airTemperatureF, 72.5)
        XCTAssertEqual(created.conditions.skyCondition, .partlyCloudy)
        XCTAssertEqual(created.conditions.waterTemperatureF, 66)
        XCTAssertEqual(created.conditions.waterClarity, .stained)
        XCTAssertEqual(created.lureText, "Green pumpkin jig")
        XCTAssertEqual(created.rodReel, "7-foot medium / spinning")
        XCTAssertEqual(created.notes, "Wind picked up after noon.")
        XCTAssertFalse(created.released)
        XCTAssertEqual(created.syncState, .pending)
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 1)
    }

    func testMinimalRecordUsesPhaseTwoDefaults() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let record = CatchRecord(ownerID: ownerID, species: "Bluegill", caughtAt: .now)
        let operation = OutboxOperation(ownerID: ownerID, catchID: record.id)
        store.container.mainContext.insert(record)
        store.container.mainContext.insert(operation)
        try store.container.mainContext.save()

        let item = try XCTUnwrap(store.repository.list(ownerID: ownerID).first)
        XCTAssertNil(item.weight)
        XCTAssertNil(item.length)
        XCTAssertNil(item.location)
        XCTAssertNil(item.coordinate)
        XCTAssertEqual(item.conditions, .empty)
        XCTAssertNil(item.lureText)
        XCTAssertNil(item.rodReel)
        XCTAssertNil(item.notes)
        XCTAssertTrue(item.released)
        XCTAssertNil(item.deletedAt)
        XCTAssertEqual(item.remoteVersion, 0)
        XCTAssertEqual(try store.repository.pendingMutations(ownerID: ownerID).first?.kind, .create)
    }

    func testListIsOwnerScopedNewestFirstAndHidesTombstones() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let otherOwnerID = UUID()
        let older = try store.repository.create(NewCatch(
            ownerID: ownerID,
            species: "Bluegill",
            caughtAt: Date(timeIntervalSince1970: 100)
        ))
        let newer = try store.repository.create(NewCatch(
            ownerID: ownerID,
            species: "Walleye",
            caughtAt: Date(timeIntervalSince1970: 200)
        ))
        _ = try store.repository.create(NewCatch(
            ownerID: otherOwnerID,
            species: "Northern Pike",
            caughtAt: Date(timeIntervalSince1970: 300)
        ))

        XCTAssertEqual(try store.repository.list(ownerID: ownerID).map(\.id), [newer.id, older.id])
        try store.repository.delete(id: newer.id, ownerID: ownerID)
        XCTAssertEqual(try store.repository.list(ownerID: ownerID).map(\.id), [older.id])
    }

    func testValidationRejectsMissingSpeciesAndInvalidMeasurements() throws {
        let store = try makeStore()
        let ownerID = UUID()
        XCTAssertThrowsError(try store.repository.create(NewCatch(
            ownerID: ownerID,
            species: "   ",
            caughtAt: .now
        ))) { error in
            XCTAssertEqual(error as? CatchValidationError, .speciesRequired)
        }
        XCTAssertThrowsError(try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(species: "Perch", weight: -0.1)
        ))) { error in
            XCTAssertEqual(error as? CatchValidationError, .invalidWeight)
        }
        XCTAssertThrowsError(try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(species: "Perch", length: .infinity)
        ))) { error in
            XCTAssertEqual(error as? CatchValidationError, .invalidLength)
        }
        XCTAssertThrowsError(try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(
                species: "Perch",
                conditions: CatchConditions(
                    airTemperatureF: .nan,
                    skyCondition: nil,
                    waterTemperatureF: nil,
                    waterClarity: nil
                )
            )
        ))) { error in
            XCTAssertEqual(error as? CatchValidationError, .invalidTemperature)
        }
    }

    func testUnsyncedCreateThenDeleteCancelsCatchAndOutbox() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let created = try store.repository.create(NewCatch(ownerID: ownerID, species: "Perch", caughtAt: .now))

        try store.repository.delete(id: created.id, ownerID: ownerID)

        XCTAssertTrue(try store.repository.list(ownerID: ownerID).isEmpty)
        XCTAssertNil(try store.repository.item(id: created.id, ownerID: ownerID))
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 0)
    }

    func testSavingUnchangedSyncedCatchDoesNotQueueMutation() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remoteStore = InMemoryCatchRemoteStore()
        let coordinator = SyncCoordinator(repository: store.repository, remoteStore: remoteStore)
        let created = try store.repository.create(NewCatch(ownerID: ownerID, species: "Perch", caughtAt: .now))
        await coordinator.sync(ownerID: ownerID)
        let synced = try XCTUnwrap(store.repository.item(id: created.id, ownerID: ownerID))

        let unchanged = try store.repository.update(id: synced.id, ownerID: ownerID, values: synced.values)

        XCTAssertEqual(unchanged.updatedAt, synced.updatedAt)
        XCTAssertEqual(unchanged.syncState, .synced)
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 0)
    }

    func testOrphanedOutboxOperationFailsExplicitly() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let missingCatchID = UUID()
        store.container.mainContext.insert(OutboxOperation(ownerID: ownerID, catchID: missingCatchID))
        try store.container.mainContext.save()

        XCTAssertThrowsError(try store.repository.pendingMutations(ownerID: ownerID)) { error in
            XCTAssertEqual(error as? CatchRepositoryError, .missingCatch(missingCatchID))
        }
    }

    func testMergeSkipsIdenticalRemoteCatch() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remoteCatch = remoteCatch(ownerID: ownerID, species: "Bluegill")

        XCTAssertTrue(try store.repository.merge([remoteCatch], ownerID: ownerID))
        XCTAssertFalse(try store.repository.merge([remoteCatch], ownerID: ownerID))
    }

    private func makeStore() throws -> TestStore {
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return TestStore(container: container)
    }

    private func values(
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        caughtAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        location: String? = nil,
        coordinate: CatchCoordinate? = nil,
        conditions: CatchConditions = .empty,
        lureText: String? = nil,
        rodReel: String? = nil,
        notes: String? = nil,
        released: Bool = true
    ) -> CatchValues {
        CatchValues(
            species: species,
            weight: weight,
            length: length,
            caughtAt: caughtAt,
            location: location,
            coordinate: coordinate,
            conditions: conditions,
            lureText: lureText,
            rodReel: rodReel,
            notes: notes,
            released: released
        )
    }

    private func remoteCatch(ownerID: UUID, species: String) -> RemoteCatch {
        RemoteCatch(
            id: UUID(),
            ownerID: ownerID,
            values: values(species: species),
            createdAt: Date(timeIntervalSince1970: 90),
            updatedAt: Date(timeIntervalSince1970: 90),
            deletedAt: nil,
            version: 1
        )
    }
}

final class CatchFormattingTests: XCTestCase {
    func testDecimalParsingAndOptionalBlank() throws {
        XCTAssertEqual(try CatchFormatting.parseOptionalMeasurement(" 12.5 ", field: .weight), 12.5)
        XCTAssertNil(try CatchFormatting.parseOptionalMeasurement("   ", field: .length))
    }

    func testImperialDisplayFormatting() {
        XCTAssertEqual(CatchFormatting.weight(12.54), "12.5 lb")
        XCTAssertEqual(CatchFormatting.length(18.5), "18.5 in")
        XCTAssertEqual(CatchFormatting.temperature(72.25), "72.2°F")
    }

    func testTemperatureParsingAllowsNegativeValuesAndRejectsNonNumericInput() throws {
        XCTAssertEqual(try CatchFormatting.parseOptionalTemperature(" -4.5 "), -4.5)
        XCTAssertNil(try CatchFormatting.parseOptionalTemperature("   "))
        XCTAssertThrowsError(try CatchFormatting.parseOptionalTemperature("warm")) { error in
            XCTAssertEqual(error as? CatchValidationError, .invalidTemperature)
        }
    }
}

final class CatchTransportTests: XCTestCase {
    func testUpdatePayloadClearsOptionalsWithoutWritingIdentityFields() throws {
        let remote = RemoteCatch(
            id: UUID(),
            ownerID: UUID(),
            values: CatchValues(
                species: "Perch",
                weight: nil,
                length: nil,
                caughtAt: Date(timeIntervalSince1970: 1_700_000_000),
                location: nil,
                conditions: .empty,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: Date(timeIntervalSince1970: 1_699_999_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            deletedAt: nil,
            version: 2
        )

        let data = try JSONEncoder().encode(CatchUpdateDTO(remote))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["id"])
        XCTAssertNil(object["owner_id"])
        XCTAssertNil(object["created_at"])
        for key in [
            "weight", "length", "location", "latitude", "longitude", "air_temp_f", "sky_condition",
            "water_temp_f", "water_clarity", "lure_text", "rod_reel", "notes", "deleted_at"
        ] {
            XCTAssertTrue(object[key] is NSNull, "Expected explicit null for \(key)")
        }
    }
}

@MainActor
private final class TestStore {
    let container: ModelContainer
    let repository: SwiftDataCatchRepository

    init(container: ModelContainer) {
        self.container = container
        repository = SwiftDataCatchRepository(modelContext: container.mainContext)
    }
}
