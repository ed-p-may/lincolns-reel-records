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
    private var hasResult = false
    private var result: AccountSession?
    private var continuation: CheckedContinuation<AccountSession?, Never>?

    init(onRestore: @escaping @Sendable () -> Void) {
        self.onRestore = onRestore
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

    func signOut() async throws {
        throw URLError(.notConnectedToInternet)
    }

    func deleteAccount() async throws {
        throw URLError(.notConnectedToInternet)
    }
}
