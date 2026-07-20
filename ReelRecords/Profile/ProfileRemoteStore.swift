import Foundation
import Supabase

protocol ProfileRemoteStore: Sendable {
    func upload(data: Data, path: String) async throws
    func apply(_ mutation: PendingProfileMutation) async throws -> ProfileMutationResult
    func remove(paths: [String]) async throws
    func download(path: String) async throws -> Data
    func fetch(ownerID: UUID) async throws -> RemoteProfile?
}

private struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let username: String
    let displayName: String?
    let homeWater: String?
    let avatarStoragePath: String?
    let anglerSince: Int?
    let createdAt: Date
    let updatedAt: Date
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case homeWater = "home_water"
        case avatarStoragePath = "avatar_storage_path"
        case anglerSince = "angler_since"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
    }

    var remoteValue: RemoteProfile {
        RemoteProfile(
            ownerID: id,
            username: username,
            values: ProfileValues(
                displayName: displayName,
                homeWater: homeWater,
                anglerSince: anglerSince
            ),
            avatarStoragePath: avatarStoragePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version
        )
    }
}

private struct ProfileUpdateDTO: Encodable, Sendable {
    let profile: RemoteProfile

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case homeWater = "home_water"
        case avatarStoragePath = "avatar_storage_path"
        case anglerSince = "angler_since"
        case updatedAt = "updated_at"
        case version
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile.values.displayName, forKey: .displayName)
        try container.encode(profile.values.homeWater, forKey: .homeWater)
        try container.encode(profile.avatarStoragePath, forKey: .avatarStoragePath)
        try container.encode(profile.values.anglerSince, forKey: .anglerSince)
        try container.encode(profile.updatedAt, forKey: .updatedAt)
        try container.encode(profile.version, forKey: .version)
    }
}

actor SupabaseProfileRemoteStore: ProfileRemoteStore {
    private static let bucket = "avatars"
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

    func apply(_ mutation: PendingProfileMutation) async throws -> ProfileMutationResult {
        let rows: [ProfileDTO] = try await client
            .from("profiles")
            .update(ProfileUpdateDTO(profile: mutation.profile))
            .eq("id", value: mutation.profile.ownerID.uuidString)
            .eq("version", value: String(mutation.expectedVersion))
            .select()
            .execute()
            .value
        if let remote = rows.first?.remoteValue {
            return .applied(remote)
        }
        let existing = try await fetch(ownerID: mutation.profile.ownerID)
        if let existing, existing.hasSameMutationPayload(as: mutation.profile) {
            return .applied(existing)
        }
        return .conflict(existing)
    }

    func remove(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        _ = try await client.storage.from(Self.bucket).remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await client.storage.from(Self.bucket).download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> RemoteProfile? {
        let rows: [ProfileDTO] = try await client
            .from("profiles")
            .select()
            .eq("id", value: ownerID.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.remoteValue
    }
}

actor InMemoryProfileRemoteStore: ProfileRemoteStore {
    private var profiles: [UUID: RemoteProfile] = [:]
    private var objects: [String: Data] = [:]

    init(profile: RemoteProfile? = nil) {
        if let profile {
            profiles[profile.ownerID] = profile
        }
    }

    func upload(data: Data, path: String) {
        objects[path] = data
    }

    func apply(_ mutation: PendingProfileMutation) -> ProfileMutationResult {
        guard let existing = profiles[mutation.profile.ownerID] else { return .conflict(nil) }
        if existing.hasSameMutationPayload(as: mutation.profile) {
            return .applied(existing)
        }
        guard existing.version == mutation.expectedVersion else { return .conflict(existing) }
        profiles[mutation.profile.ownerID] = mutation.profile
        return .applied(mutation.profile)
    }

    func remove(paths: [String]) {
        paths.forEach { objects[$0] = nil }
    }

    func download(path: String) throws -> Data {
        guard let data = objects[path] else { throw URLError(.fileDoesNotExist) }
        return data
    }

    func fetch(ownerID: UUID) -> RemoteProfile? {
        profiles[ownerID]
    }

    func seed(_ profile: RemoteProfile, data: Data? = nil) {
        profiles[profile.ownerID] = profile
        if let data, let path = profile.avatarStoragePath {
            objects[path] = data
        }
    }

    func containsObject(path: String) -> Bool {
        objects[path] != nil
    }
}

private extension RemoteProfile {
    func hasSameMutationPayload(as other: RemoteProfile) -> Bool {
        ownerID == other.ownerID
            && values == other.values
            && avatarStoragePath == other.avatarStoragePath
            && version == other.version
    }
}
