import Foundation
import Supabase

protocol CatchPhotoRemoteStore: Sendable {
    func upload(data: Data, path: String) async throws
    func apply(_ mutation: PendingPhotoMutation) async throws -> PhotoMutationResult
    func remove(path: String) async throws
    func download(path: String) async throws -> Data
    func fetch(ownerID: UUID) async throws -> [RemoteCatchPhoto]
}

private struct CatchPhotoDTO: Codable, Sendable {
    let id: UUID
    let catchID: UUID
    let storagePath: String
    let position: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case catchID = "catch_id"
        case storagePath = "storage_path"
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    init(_ photo: RemoteCatchPhoto) {
        id = photo.id
        catchID = photo.catchID
        storagePath = photo.storagePath
        position = photo.position
        createdAt = photo.createdAt
        updatedAt = photo.updatedAt
        deletedAt = photo.deletedAt
        version = photo.version
    }

    func remoteValue(ownerID: UUID) -> RemoteCatchPhoto {
        RemoteCatchPhoto(
            id: id,
            ownerID: ownerID,
            catchID: catchID,
            storagePath: storagePath,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}

private struct CatchPhotoUpdateDTO: Encodable, Sendable {
    let storagePath: String
    let position: Int
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case storagePath = "storage_path"
        case position
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    init(_ photo: RemoteCatchPhoto) {
        storagePath = photo.storagePath
        position = photo.position
        updatedAt = photo.updatedAt
        deletedAt = photo.deletedAt
        version = photo.version
    }
}

actor SupabaseCatchPhotoRemoteStore: CatchPhotoRemoteStore {
    private static let bucket = "catch-photos"
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

    func apply(_ mutation: PendingPhotoMutation) async throws -> PhotoMutationResult {
        switch mutation.kind {
        case .create:
            try await create(mutation)
        case .update, .delete:
            try await update(mutation)
        }
    }

    func remove(path: String) async throws {
        _ = try await client.storage.from(Self.bucket).remove(paths: [path])
    }

    func download(path: String) async throws -> Data {
        try await client.storage.from(Self.bucket).download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteCatchPhoto] {
        let rows: [CatchPhotoDTO] = try await client
            .from("catch_photos")
            .select()
            .order("position", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.remoteValue(ownerID: ownerID) }
    }

    private func create(_ mutation: PendingPhotoMutation) async throws -> PhotoMutationResult {
        do {
            let rows: [CatchPhotoDTO] = try await client
                .from("catch_photos")
                .insert(CatchPhotoDTO(mutation.photo))
                .select()
                .execute()
                .value
            guard let remote = rows.first?.remoteValue(ownerID: mutation.photo.ownerID) else {
                return try await .conflict(fetch(id: mutation.photo.id, ownerID: mutation.photo.ownerID))
            }
            return .applied(remote)
        } catch {
            if let existing = try? await fetch(id: mutation.photo.id, ownerID: mutation.photo.ownerID) {
                return existing.hasSameMutationPayload(as: mutation.photo)
                    ? .applied(existing)
                    : .conflict(existing)
            }
            throw error
        }
    }

    private func update(_ mutation: PendingPhotoMutation) async throws -> PhotoMutationResult {
        let rows: [CatchPhotoDTO] = try await client
            .from("catch_photos")
            .update(CatchPhotoUpdateDTO(mutation.photo))
            .eq("id", value: mutation.photo.id.uuidString)
            .eq("version", value: String(mutation.expectedVersion))
            .select()
            .execute()
            .value
        if let remote = rows.first?.remoteValue(ownerID: mutation.photo.ownerID) {
            return .applied(remote)
        }
        let existing = try await fetch(id: mutation.photo.id, ownerID: mutation.photo.ownerID)
        if let existing, existing.hasSameMutationPayload(as: mutation.photo) {
            return .applied(existing)
        }
        if existing == nil, mutation.kind == .delete {
            return .applied(mutation.photo)
        }
        return .conflict(existing)
    }

    private func fetch(id: UUID, ownerID: UUID) async throws -> RemoteCatchPhoto? {
        let rows: [CatchPhotoDTO] = try await client
            .from("catch_photos")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.remoteValue(ownerID: ownerID)
    }
}

actor InMemoryCatchPhotoRemoteStore: CatchPhotoRemoteStore {
    private var photos: [UUID: RemoteCatchPhoto] = [:]
    private var objects: [String: Data] = [:]

    func upload(data: Data, path: String) {
        objects[path] = data
    }

    func apply(_ mutation: PendingPhotoMutation) -> PhotoMutationResult {
        if let existing = photos[mutation.photo.id] {
            if existing.hasSameMutationPayload(as: mutation.photo) {
                return .applied(existing)
            }
            guard mutation.kind != .create, existing.version == mutation.expectedVersion else {
                return .conflict(existing)
            }
        } else if mutation.kind == .delete {
            return .applied(mutation.photo)
        } else if mutation.kind != .create {
            return .conflict(nil)
        }
        photos[mutation.photo.id] = mutation.photo
        return .applied(mutation.photo)
    }

    func remove(path: String) {
        objects[path] = nil
    }

    func download(path: String) throws -> Data {
        guard let data = objects[path] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }

    func fetch(ownerID: UUID) -> [RemoteCatchPhoto] {
        photos.values
            .filter { $0.ownerID == ownerID }
            .sorted {
                ($0.position, $0.createdAt, $0.id.uuidString)
                    < ($1.position, $1.createdAt, $1.id.uuidString)
            }
    }

    func seed(_ photo: RemoteCatchPhoto, data: Data?) {
        photos[photo.id] = photo
        if let data {
            objects[photo.storagePath] = data
        }
    }

    func containsObject(path: String) -> Bool {
        objects[path] != nil
    }
}

private extension RemoteCatchPhoto {
    func hasSameMutationPayload(as other: RemoteCatchPhoto) -> Bool {
        id == other.id
            && ownerID == other.ownerID
            && catchID == other.catchID
            && storagePath == other.storagePath
            && position == other.position
            && version == other.version
            && (deletedAt == nil) == (other.deletedAt == nil)
    }
}
