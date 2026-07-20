import Foundation
import Supabase

protocol AuthBackend: Sendable {
    func restoreSession() async throws -> AccountSession?
    func signIn(email: String, password: String) async throws -> AccountSession
    func signUp(username: String, email: String, password: String) async throws -> AccountSession
    func requestPasswordReset(email: String) async throws
    func recoverSession(from url: URL) async throws -> AccountSession
    func updatePassword(_ password: String) async throws
    func signOut() async throws
    func deleteAccount() async throws
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

    func requestPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: AuthConfiguration.passwordRecoveryURL
        )
    }

    func recoverSession(from url: URL) async throws -> AccountSession {
        let session = try await client.auth.session(from: url)
        return try await account(for: session.user.id, email: session.user.email ?? "")
    }

    func updatePassword(_ password: String) async throws {
        try await client.auth.update(user: UserAttributes(password: password))
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        try? await client.auth.signOut(scope: .local)
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

    func requestPasswordReset(email _: String) async throws {}

    func recoverSession(from _: URL) async throws -> AccountSession {
        guard let account else {
            throw AuthServiceError.sessionUnavailable
        }
        return account
    }

    func updatePassword(_: String) async throws {}

    func signOut() async throws {
        account = nil
    }

    func deleteAccount() async throws {
        account = nil
    }
}
