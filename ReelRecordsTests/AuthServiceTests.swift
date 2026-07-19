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

        await service.signOut(pendingCatchCount: 2)

        XCTAssertEqual(service.signOutFailure, .pendingCatches(2))
        XCTAssertEqual(service.signOutFailure?.canRetrySync, true)
        XCTAssertEqual(service.state, .authenticated(account))
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
}
