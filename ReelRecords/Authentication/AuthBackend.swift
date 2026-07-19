import Foundation
import Supabase

protocol AuthBackend: Sendable {
    func restoreSession() async throws -> AccountSession?
    func signIn(email: String, password: String) async throws -> AccountSession
    func signUp(username: String, email: String, password: String) async throws -> AccountSession
    func signOut() async throws
}

actor SupabaseAuthBackend: AuthBackend {
    private struct ProfileDTO: Decodable, Sendable {
        let username: String
    }

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async throws -> AccountSession? {
        do {
            let session = try await client.auth.session
            return try await account(for: session.user.id, email: session.user.email ?? "")
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AccountSession {
        let session = try await client.auth.signIn(email: email, password: password)
        return try await account(for: session.user.id, email: session.user.email ?? email)
    }

    func signUp(username: String, email: String, password: String) async throws -> AccountSession {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)]
        )
        guard let session = response.session else {
            throw AuthServiceError.sessionUnavailable
        }
        return AccountSession(
            ownerID: session.user.id,
            email: session.user.email ?? email,
            username: username,
            isOffline: false
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func account(for ownerID: UUID, email: String) async throws -> AccountSession {
        let profile: ProfileDTO = try await client
            .from("profiles")
            .select("username")
            .eq("id", value: ownerID.uuidString)
            .single()
            .execute()
            .value

        return AccountSession(
            ownerID: ownerID,
            email: email,
            username: profile.username,
            isOffline: false
        )
    }
}

actor MockAuthBackend: AuthBackend {
    private var account: AccountSession?

    init(account: AccountSession?) {
        self.account = account
    }

    func restoreSession() async throws -> AccountSession? {
        account
    }

    func signIn(email: String, password _: String) async throws -> AccountSession {
        let session = account ?? AccountSession(
            ownerID: UUID(),
            email: email,
            username: email.split(separator: "@").first.map(String.init) ?? "angler",
            isOffline: false
        )
        account = session
        return session
    }

    func signUp(username: String, email: String, password _: String) async throws -> AccountSession {
        let session = AccountSession(
            ownerID: UUID(),
            email: email,
            username: username,
            isOffline: false
        )
        account = session
        return session
    }

    func signOut() async throws {
        account = nil
    }
}
