import Foundation
import Supabase

protocol CatchRemoteStore: Sendable {
    func upsert(_ catchItems: [RemoteCatch]) async throws
    func fetch(ownerID: UUID) async throws -> [RemoteCatch]
}

private struct CatchDTO: Codable, Sendable {
    let id: UUID
    let ownerID: UUID
    let species: String
    let caughtAt: Date
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case species
        case caughtAt = "caught_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ catchItem: RemoteCatch) {
        id = catchItem.id
        ownerID = catchItem.ownerID
        species = catchItem.species
        caughtAt = catchItem.caughtAt
        createdAt = catchItem.createdAt
        updatedAt = catchItem.updatedAt
    }

    var remoteValue: RemoteCatch {
        RemoteCatch(
            id: id,
            ownerID: ownerID,
            species: species,
            caughtAt: caughtAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

actor SupabaseCatchRemoteStore: CatchRemoteStore {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upsert(_ catchItems: [RemoteCatch]) async throws {
        guard !catchItems.isEmpty else { return }
        try await client
            .from("catches")
            .upsert(catchItems.map(CatchDTO.init), onConflict: "id")
            .execute()
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
}

actor InMemoryCatchRemoteStore: CatchRemoteStore {
    private var catches: [UUID: RemoteCatch] = [:]

    func upsert(_ catchItems: [RemoteCatch]) async throws {
        for catchItem in catchItems {
            catches[catchItem.id] = catchItem
        }
    }

    func fetch(ownerID: UUID) async throws -> [RemoteCatch] {
        catches.values
            .filter { $0.ownerID == ownerID }
            .sorted { $0.caughtAt > $1.caughtAt }
    }
}
