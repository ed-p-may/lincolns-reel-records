import Foundation
import Supabase

protocol CatchRemoteStore: Sendable {
    func apply(_ mutation: PendingCatchMutation) async throws -> CatchMutationResult
    func fetch(ownerID: UUID) async throws -> [RemoteCatch]
}

private struct CatchDTO: Codable, Sendable {
    let id: UUID
    let ownerID: UUID
    let species: String
    let weight: Double?
    let length: Double?
    let caughtAt: Date
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let lureText: String?
    let rodReel: String?
    let notes: String?
    let released: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case species
        case weight
        case length
        case caughtAt = "caught_at"
        case location
        case latitude
        case longitude
        case lureText = "lure_text"
        case rodReel = "rod_reel"
        case notes
        case released
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    init(_ catchItem: RemoteCatch) {
        id = catchItem.id
        ownerID = catchItem.ownerID
        species = catchItem.values.species
        weight = catchItem.values.weight
        length = catchItem.values.length
        caughtAt = catchItem.values.caughtAt
        location = catchItem.values.location
        latitude = catchItem.values.coordinate?.latitude
        longitude = catchItem.values.coordinate?.longitude
        lureText = catchItem.values.lureText
        rodReel = catchItem.values.rodReel
        notes = catchItem.values.notes
        released = catchItem.values.released
        createdAt = catchItem.createdAt
        updatedAt = catchItem.updatedAt
        deletedAt = catchItem.deletedAt
        version = catchItem.version
    }

    var remoteValue: RemoteCatch {
        RemoteCatch(
            id: id,
            ownerID: ownerID,
            values: CatchValues(
                species: species,
                weight: weight,
                length: length,
                caughtAt: caughtAt,
                location: location,
                coordinate: CatchCoordinate(latitude: latitude, longitude: longitude),
                lureText: lureText,
                rodReel: rodReel,
                notes: notes,
                released: released
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}

struct CatchUpdateDTO: Encodable, Sendable {
    let values: CatchValues
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case species
        case weight
        case length
        case caughtAt = "caught_at"
        case location
        case latitude
        case longitude
        case lureText = "lure_text"
        case rodReel = "rod_reel"
        case notes
        case released
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    init(_ catchItem: RemoteCatch) {
        values = catchItem.values
        updatedAt = catchItem.updatedAt
        deletedAt = catchItem.deletedAt
        version = catchItem.version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values.species, forKey: .species)
        try container.encode(values.weight, forKey: .weight)
        try container.encode(values.length, forKey: .length)
        try container.encode(values.caughtAt, forKey: .caughtAt)
        try container.encode(values.location, forKey: .location)
        try container.encode(values.coordinate?.latitude, forKey: .latitude)
        try container.encode(values.coordinate?.longitude, forKey: .longitude)
        try container.encode(values.lureText, forKey: .lureText)
        try container.encode(values.rodReel, forKey: .rodReel)
        try container.encode(values.notes, forKey: .notes)
        try container.encode(values.released, forKey: .released)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
        try container.encode(version, forKey: .version)
    }
}

actor SupabaseCatchRemoteStore: CatchRemoteStore {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func apply(_ mutation: PendingCatchMutation) async throws -> CatchMutationResult {
        switch mutation.kind {
        case .create:
            try await create(mutation)
        case .update, .delete:
            try await update(mutation)
        }
    }

    func fetch(ownerID: UUID) async throws -> [RemoteCatch] {
        let rows: [CatchDTO] = try await client
            .from("catches")
            .select()
            .eq("owner_id", value: ownerID.uuidString)
            .order("caught_at", ascending: false)
            .execute()
            .value
        return rows.map(\.remoteValue)
    }

    private func create(_ mutation: PendingCatchMutation) async throws -> CatchMutationResult {
        do {
            let rows: [CatchDTO] = try await client
                .from("catches")
                .insert(CatchDTO(mutation.catchItem))
                .select()
                .execute()
                .value
            guard let remote = rows.first?.remoteValue else {
                return try await .conflict(fetch(id: mutation.catchItem.id, ownerID: mutation.catchItem.ownerID))
            }
            return .applied(remote)
        } catch {
            if let existing = try? await fetch(id: mutation.catchItem.id, ownerID: mutation.catchItem.ownerID) {
                return existing.hasSameMutationPayload(as: mutation.catchItem)
                    ? .applied(existing)
                    : .conflict(existing)
            }
            throw error
        }
    }

    private func update(_ mutation: PendingCatchMutation) async throws -> CatchMutationResult {
        let rows: [CatchDTO] = try await client
            .from("catches")
            .update(CatchUpdateDTO(mutation.catchItem))
            .eq("id", value: mutation.catchItem.id.uuidString)
            .eq("owner_id", value: mutation.catchItem.ownerID.uuidString)
            .eq("version", value: String(mutation.expectedVersion))
            .select()
            .execute()
            .value
        if let remote = rows.first?.remoteValue {
            return .applied(remote)
        }

        let existing = try await fetch(id: mutation.catchItem.id, ownerID: mutation.catchItem.ownerID)
        if let existing, existing.hasSameMutationPayload(as: mutation.catchItem) {
            return .applied(existing)
        }
        if existing == nil, mutation.kind == .delete {
            return .applied(mutation.catchItem)
        }
        return .conflict(existing)
    }

    private func fetch(id: UUID, ownerID: UUID) async throws -> RemoteCatch? {
        let rows: [CatchDTO] = try await client
            .from("catches")
            .select()
            .eq("id", value: id.uuidString)
            .eq("owner_id", value: ownerID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.remoteValue
    }
}

actor InMemoryCatchRemoteStore: CatchRemoteStore {
    private var catches: [UUID: RemoteCatch] = [:]

    func apply(_ mutation: PendingCatchMutation) async throws -> CatchMutationResult {
        if let existing = catches[mutation.catchItem.id] {
            if existing.hasSameMutationPayload(as: mutation.catchItem) {
                return .applied(existing)
            }
            guard mutation.kind != .create, existing.version == mutation.expectedVersion else {
                return .conflict(existing)
            }
        } else if mutation.kind == .delete {
            return .applied(mutation.catchItem)
        } else if mutation.kind != .create {
            return .conflict(nil)
        }

        catches[mutation.catchItem.id] = mutation.catchItem
        return .applied(mutation.catchItem)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteCatch] {
        catches.values
            .filter { $0.ownerID == ownerID }
            .sorted { $0.values.caughtAt > $1.values.caughtAt }
    }

    func seed(_ catchItem: RemoteCatch) {
        catches[catchItem.id] = catchItem
    }
}

private extension RemoteCatch {
    func hasSameMutationPayload(as other: RemoteCatch) -> Bool {
        id == other.id
            && ownerID == other.ownerID
            && version == other.version
            && values.hasSameMutationPayload(as: other.values)
            && (deletedAt == nil) == (other.deletedAt == nil)
    }
}

private extension CatchValues {
    func hasSameMutationPayload(as other: CatchValues) -> Bool {
        species == other.species
            && weight == other.weight
            && length == other.length
            && abs(caughtAt.timeIntervalSince(other.caughtAt)) < 0.01
            && location == other.location
            && coordinate == other.coordinate
            && lureText == other.lureText
            && rodReel == other.rodReel
            && notes == other.notes
            && released == other.released
    }
}
