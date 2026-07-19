import Foundation
import Observation

@MainActor
@Observable
final class AuthService {
    private enum CacheKey {
        static let account = "reel-records.cached-account"
    }

    private let backend: any AuthBackend
    private let defaults: UserDefaults
    private var hasRestored = false

    private(set) var state: AuthState = .loading
    private(set) var isWorking = false
    private(set) var signOutFailure: SignOutFailure?
    var errorMessage: String?

    init(backend: any AuthBackend, defaults: UserDefaults = .standard) {
        self.backend = backend
        self.defaults = defaults
    }

    func restoreSession() async {
        guard !hasRestored else { return }
        hasRestored = true

        let cachedAccount = cachedAccount()
        if var cachedAccount {
            cachedAccount.isOffline = true
            state = .authenticated(cachedAccount)
        }

        do {
            if let account = try await backend.restoreSession() {
                authenticate(account)
            } else {
                clearCachedAccount()
                state = .signedOut
            }
        } catch where error.isConnectivityFailure {
            if cachedAccount == nil {
                state = .signedOut
                errorMessage = "Connect to the internet to sign in for the first time."
            }
        } catch {
            clearCachedAccount()
            state = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        await performAuthentication {
            try await backend.signIn(email: email, password: password)
        }
    }

    func signUp(username: String, email: String, password: String) async {
        await performAuthentication {
            try await backend.signUp(username: username, email: email, password: password)
        }
    }

    func signOut(pendingChangeCount: Int) async {
        signOutFailure = nil
        guard pendingChangeCount == 0 else {
            signOutFailure = .pendingChanges(pendingChangeCount)
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            try await backend.signOut()
            clearCachedAccount()
            state = .signedOut
        } catch {
            signOutFailure = .backend(error.localizedDescription)
        }
    }

    func blockSignOut(for error: Error) {
        signOutFailure = .localStore(error.localizedDescription)
    }

    func clearSignOutFailure() {
        signOutFailure = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func performAuthentication(_ operation: () async throws -> AccountSession) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await authenticate(operation())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate(_ account: AccountSession) {
        var onlineAccount = account
        onlineAccount.isOffline = false
        cache(onlineAccount)
        state = .authenticated(onlineAccount)
    }

    private func cache(_ account: AccountSession) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: CacheKey.account)
    }

    private func cachedAccount() -> AccountSession? {
        guard let data = defaults.data(forKey: CacheKey.account) else { return nil }
        return try? JSONDecoder().decode(AccountSession.self, from: data)
    }

    private func clearCachedAccount() {
        defaults.removeObject(forKey: CacheKey.account)
    }
}
