import Foundation
@testable import LincolnReelRecords
import XCTest

@MainActor
final class AuthServiceTests: XCTestCase {
    func testCachedAuthenticatedAccountReopensOffline() async throws {
        let suiteName = "AuthServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let onlineService = AuthService(backend: MockAuthBackend(account: account), defaults: defaults)
        await onlineService.restoreSession()

        let offlineService = AuthService(backend: OfflineAuthBackend(), defaults: defaults)
        await offlineService.restoreSession()

        guard case let .authenticated(restoredAccount) = offlineService.state else {
            return XCTFail("Expected a cached authenticated account")
        }
        XCTAssertEqual(restoredAccount.ownerID, account.ownerID)
        XCTAssertTrue(restoredAccount.isOffline)
    }

    func testCachedAccountOpensBeforeBackendRestoreCompletes() async throws {
        let suiteName = "AuthServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let onlineService = AuthService(backend: MockAuthBackend(account: account), defaults: defaults)
        await onlineService.restoreSession()

        let restoreStarted = expectation(description: "Backend restore started")
        let delayedBackend = DelayedAuthBackend { restoreStarted.fulfill() }
        let restoringService = AuthService(backend: delayedBackend, defaults: defaults)
        let restoreTask = Task { await restoringService.restoreSession() }

        await fulfillment(of: [restoreStarted], timeout: 1)

        guard case let .authenticated(restoredAccount) = restoringService.state else {
            return XCTFail("Expected cached account before backend restore completed")
        }
        XCTAssertEqual(restoredAccount.ownerID, account.ownerID)
        XCTAssertTrue(restoredAccount.isOffline)

        await delayedBackend.finish(with: account)
        await restoreTask.value
    }

    func testSignOutIsBlockedByPendingCatch() async {
        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let backend = MockAuthBackend(account: account)
        let service = AuthService(backend: backend)
        await service.restoreSession()

        await service.signOut(pendingChangeCount: 2)

        XCTAssertEqual(service.signOutFailure, .pendingChanges(2))
        XCTAssertEqual(service.signOutFailure?.canRetrySync, true)
        XCTAssertEqual(service.state, .authenticated(account))
    }

    func testDeleteAccountPurgesLocalDataAndSignsOut() async {
        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let service = AuthService(backend: MockAuthBackend(account: account))
        await service.restoreSession()
        var didPurge = false

        let deleted = await service.deleteAccount { didPurge = true }

        XCTAssertTrue(deleted)
        XCTAssertTrue(didPurge)
        XCTAssertEqual(service.state, .signedOut)
    }

    func testDeleteAccountRetriesLocalPurgeWithoutRepeatingHostedDeletion() async {
        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let backend = CountingDeleteAuthBackend(account: account)
        let service = AuthService(backend: backend)
        await service.restoreSession()
        var purgeAttempts = 0

        let firstResult = await service.deleteAccount {
            purgeAttempts += 1
            throw LocalPurgeFailure()
        }
        XCTAssertFalse(firstResult)
        XCTAssertTrue(service.hasPendingLocalAccountDeletion)
        XCTAssertEqual(service.state, .authenticated(account))

        let retryResult = await service.deleteAccount { purgeAttempts += 1 }
        let hostedDeleteCount = await backend.deleteCount
        XCTAssertTrue(retryResult)
        XCTAssertEqual(purgeAttempts, 2)
        XCTAssertEqual(hostedDeleteCount, 1)
        XCTAssertEqual(service.state, .signedOut)
    }

    func testPasswordRecoveryAuthenticatesCallbackAccountAndUpdatesPassword() async throws {
        let account = AccountSession(
            ownerID: UUID(),
            email: "angler@example.com",
            username: "angler",
            isOffline: false
        )
        let backend = PasswordRecoveryAuthBackend(account: account)
        let service = AuthService(backend: backend)
        await service.restoreSession()

        let didSend = await service.requestPasswordReset(email: account.email)
        try await service.handlePasswordRecoveryURL(
            XCTUnwrap(URL(string: "lincolnsreelrecords://reset-password?code=test"))
        )
        try await service.handlePasswordRecoveryURL(
            XCTUnwrap(URL(string: "lincolnsreelrecords://reset-password?code=test"))
        )
        await service.updateRecoveredPassword("new-password")

        XCTAssertTrue(didSend)
        XCTAssertFalse(service.isPasswordRecoveryPresented)
        XCTAssertEqual(service.state, .authenticated(account))
        let requests = await backend.resetRequests
        let updatedPassword = await backend.updatedPassword
        XCTAssertEqual(requests, [account.email])
        XCTAssertEqual(updatedPassword, "new-password")
        let callbackCount = await backend.callbackCount
        XCTAssertEqual(callbackCount, 1)
    }

    func testPasswordRecoveryIgnoresUnrelatedURL() async throws {
        let backend = PasswordRecoveryAuthBackend(account: nil)
        let service = AuthService(backend: backend)

        try await service.handlePasswordRecoveryURL(XCTUnwrap(URL(string: "https://example.com/reset-password")))

        XCTAssertFalse(service.isPasswordRecoveryPresented)
        let callbackCount = await backend.callbackCount
        XCTAssertEqual(callbackCount, 0)
    }

    func testPasswordRecoveryWinsAgainstStaleStartupRestore() async throws {
        let recoveryAccount = AccountSession(
            ownerID: UUID(),
            email: "recovered@example.com",
            username: "recovered",
            isOffline: false
        )
        let restoreStarted = expectation(description: "Backend restore started")
        let backend = DelayedAuthBackend(
            onRestore: { restoreStarted.fulfill() },
            recoveryAccount: recoveryAccount
        )
        let service = AuthService(backend: backend)
        let restoreTask = Task { await service.restoreSession() }
        await fulfillment(of: [restoreStarted], timeout: 1)

        try await service.handlePasswordRecoveryURL(
            XCTUnwrap(URL(string: "lincolnsreelrecords://reset-password?code=recovery"))
        )
        await backend.finish(with: nil)
        await restoreTask.value

        XCTAssertEqual(service.state, .authenticated(recoveryAccount))
        XCTAssertTrue(service.isPasswordRecoveryPresented)
    }
}

private struct LocalPurgeFailure: LocalizedError {
    var errorDescription: String? {
        "Test purge failed."
    }
}

private actor CountingDeleteAuthBackend: AuthBackend {
    private var account: AccountSession?
    private(set) var deleteCount = 0

    init(account: AccountSession) {
        self.account = account
    }

    func restoreSession() async throws -> AccountSession? {
        account
    }

    func signIn(email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func signUp(username _: String, email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func signOut() async throws {
        account = nil
    }

    func deleteAccount() async throws {
        deleteCount += 1
        account = nil
    }
}

private actor DelayedAuthBackend: AuthBackend {
    private let onRestore: @Sendable () -> Void
    private let recoveryAccount: AccountSession?
    private var hasResult = false
    private var result: AccountSession?
    private var continuation: CheckedContinuation<AccountSession?, Never>?

    init(
        onRestore: @escaping @Sendable () -> Void,
        recoveryAccount: AccountSession? = nil
    ) {
        self.onRestore = onRestore
        self.recoveryAccount = recoveryAccount
    }

    func restoreSession() async throws -> AccountSession? {
        onRestore()
        if hasResult {
            return result
        }
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish(with account: AccountSession?) {
        hasResult = true
        result = account
        continuation?.resume(returning: account)
        continuation = nil
    }

    func signIn(email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func signUp(username _: String, email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func recoverSession(from _: URL) async throws -> AccountSession {
        guard let recoveryAccount else { throw URLError(.unsupportedURL) }
        return recoveryAccount
    }

    func signOut() async throws {
        throw URLError(.unsupportedURL)
    }

    func deleteAccount() async throws {
        throw URLError(.unsupportedURL)
    }
}

private actor OfflineAuthBackend: AuthBackend {
    func restoreSession() async throws -> AccountSession? {
        throw URLError(.notConnectedToInternet)
    }

    func signIn(email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.notConnectedToInternet)
    }

    func signUp(username _: String, email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.notConnectedToInternet)
    }

    func requestPasswordReset(email _: String) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func recoverSession(from _: URL) async throws -> AccountSession {
        throw URLError(.notConnectedToInternet)
    }

    func updatePassword(_: String) async throws {
        throw URLError(.notConnectedToInternet)
    }

    func signOut() async throws {
        throw URLError(.notConnectedToInternet)
    }

    func deleteAccount() async throws {
        throw URLError(.notConnectedToInternet)
    }
}

private actor PasswordRecoveryAuthBackend: AuthBackend {
    private let account: AccountSession?
    private(set) var resetRequests: [String] = []
    private(set) var callbackCount = 0
    private(set) var updatedPassword: String?

    init(account: AccountSession?) {
        self.account = account
    }

    func restoreSession() async throws -> AccountSession? {
        nil
    }

    func signIn(email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func signUp(username _: String, email _: String, password _: String) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func requestPasswordReset(email: String) async throws {
        resetRequests.append(email)
    }

    func recoverSession(from _: URL) async throws -> AccountSession {
        callbackCount += 1
        guard let account else { throw AuthServiceError.sessionUnavailable }
        return account
    }

    func updatePassword(_ password: String) async throws {
        updatedPassword = password
    }

    func signOut() async throws {}
    func deleteAccount() async throws {}
}

private extension AuthBackend {
    func requestPasswordReset(email _: String) async throws {
        throw URLError(.unsupportedURL)
    }

    func recoverSession(from _: URL) async throws -> AccountSession {
        throw URLError(.unsupportedURL)
    }

    func updatePassword(_: String) async throws {
        throw URLError(.unsupportedURL)
    }
}
