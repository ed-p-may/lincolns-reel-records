import Foundation
import Supabase

protocol TackleRemoteStore: Sendable {
    func upload(data: Data, path: String) async throws
    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult
    func remove(paths: [String]) async throws
    func download(path: String) async throws -> Data
    func fetch(ownerID: UUID) async throws -> [RemoteTackleItem]
}

private struct TackleItemDTO: Codable, Sendable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let type: String
    let size: String?
    let color: String?
    let brand: String?
    let photoStoragePath: String?
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case type
        case size
        case color
        case brand
        case photoStoragePath = "photo_storage_path"
        case archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    init(_ item: RemoteTackleItem) {
        id = item.id
        ownerID = item.ownerID
        name = item.values.name
        type = item.values.type.rawValue
        size = item.values.size
        color = item.values.color
        brand = item.values.brand
        photoStoragePath = item.photoStoragePath
        archived = item.values.archived
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        deletedAt = item.deletedAt
        version = item.version
    }

    var remoteValue: RemoteTackleItem {
        RemoteTackleItem(
            id: id,
            ownerID: ownerID,
            values: TackleValues(
                name: name,
                type: TackleItemType(rawValue: type) ?? .other,
                size: size,
                color: color,
                brand: brand,
                archived: archived
            ),
            photoStoragePath: photoStoragePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}

private struct TackleItemUpdateDTO: Encodable, Sendable {
    let item: RemoteTackleItem

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case size
        case color
        case brand
        case photoStoragePath = "photo_storage_path"
        case archived
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item.values.name, forKey: .name)
        try container.encode(item.values.type.rawValue, forKey: .type)
        try container.encode(item.values.size, forKey: .size)
        try container.encode(item.values.color, forKey: .color)
        try container.encode(item.values.brand, forKey: .brand)
        try container.encode(item.photoStoragePath, forKey: .photoStoragePath)
        try container.encode(item.values.archived, forKey: .archived)
        try container.encode(item.updatedAt, forKey: .updatedAt)
        try container.encode(item.deletedAt, forKey: .deletedAt)
        try container.encode(item.version, forKey: .version)
    }
}

actor SupabaseTackleRemoteStore: TackleRemoteStore {
    private static let bucket = "tackle-photos"
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(data: Data, path: String) async throws {
        try await client.storage.from(Self.bucket).upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg", upsert: true)
        )
    }

    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        switch mutation.kind {
        case .create:
            try await create(mutation)
        case .update, .delete:
            try await update(mutation)
        }
    }

    func remove(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        _ = try await client.storage.from(Self.bucket).remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await client.storage.from(Self.bucket).download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteTackleItem] {
        let rows: [TackleItemDTO] = try await client
            .from("tackle_items")
            .select()
            .eq("owner_id", value: ownerID.uuidString)
            .order("name", ascending: true)
            .execute()
            .value
        return rows.map(\.remoteValue)
    }

    private func create(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        do {
            let rows: [TackleItemDTO] = try await client
                .from("tackle_items")
                .insert(TackleItemDTO(mutation.item))
                .select()
                .execute()
                .value
            guard let remote = rows.first?.remoteValue else {
                return try await .conflict(fetch(id: mutation.item.id, ownerID: mutation.item.ownerID))
            }
            return .applied(remote)
        } catch {
            if let existing = try? await fetch(id: mutation.item.id, ownerID: mutation.item.ownerID) {
                return existing.hasSameMutationPayload(as: mutation.item)
                    ? .applied(existing)
                    : .conflict(existing)
            }
            throw error
        }
    }

    private func update(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        let rows: [TackleItemDTO] = try await client
            .from("tackle_items")
            .update(TackleItemUpdateDTO(item: mutation.item))
            .eq("id", value: mutation.item.id.uuidString)
            .eq("owner_id", value: mutation.item.ownerID.uuidString)
            .eq("version", value: String(mutation.expectedVersion))
            .select()
            .execute()
            .value
        if let remote = rows.first?.remoteValue {
            return .applied(remote)
        }
        let existing = try await fetch(id: mutation.item.id, ownerID: mutation.item.ownerID)
        if let existing, existing.hasSameMutationPayload(as: mutation.item) {
            return .applied(existing)
        }
        if existing == nil, mutation.kind == .delete {
            return .applied(mutation.item)
        }
        return .conflict(existing)
    }

    private func fetch(id: UUID, ownerID: UUID) async throws -> RemoteTackleItem? {
        let rows: [TackleItemDTO] = try await client
            .from("tackle_items")
            .select()
            .eq("id", value: id.uuidString)
            .eq("owner_id", value: ownerID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.remoteValue
    }
}

actor InMemoryTackleRemoteStore: TackleRemoteStore {
    private var items: [UUID: RemoteTackleItem] = [:]
    private var objects: [String: Data] = [:]

    func upload(data: Data, path: String) {
        objects[path] = data
    }

    func apply(_ mutation: PendingTackleMutation) -> TackleMutationResult {
        if let existing = items[mutation.item.id] {
            if existing.hasSameMutationPayload(as: mutation.item) {
                return .applied(existing)
            }
            guard mutation.kind != .create, existing.version == mutation.expectedVersion else {
                return .conflict(existing)
            }
        } else if mutation.kind == .delete {
            return .applied(mutation.item)
        } else if mutation.kind != .create {
            return .conflict(nil)
        }
        items[mutation.item.id] = mutation.item
        return .applied(mutation.item)
    }

    func remove(paths: [String]) {
        paths.forEach { objects[$0] = nil }
    }

    func download(path: String) throws -> Data {
        guard let data = objects[path] else { throw URLError(.fileDoesNotExist) }
        return data
    }

    func fetch(ownerID: UUID) -> [RemoteTackleItem] {
        items.values
            .filter { $0.ownerID == ownerID }
            .sorted { TackleDiscovery.alphabeticallyPrecedes($0.localItem, $1.localItem) }
    }

    func seed(_ item: RemoteTackleItem, data: Data? = nil) {
        items[item.id] = item
        if let data, let path = item.photoStoragePath {
            objects[path] = data
        }
    }

    func containsObject(path: String) -> Bool {
        objects[path] != nil
    }
}

private extension RemoteTackleItem {
    var localItem: TackleItem {
        TackleItem(
            id: id,
            ownerID: ownerID,
            values: values,
            photoID: photoID,
            photoStoragePath: photoStoragePath,
            photoLocalRelativePath: nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            remoteVersion: version,
            syncState: .synced,
            syncError: nil
        )
    }

    func hasSameMutationPayload(as other: RemoteTackleItem) -> Bool {
        id == other.id
            && ownerID == other.ownerID
            && values == other.values
            && photoStoragePath == other.photoStoragePath
            && version == other.version
            && (deletedAt == nil) == (other.deletedAt == nil)
    }
}
