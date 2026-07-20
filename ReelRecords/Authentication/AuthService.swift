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
    private var authenticationRevision = 0
    private var workingOperationCount = 0
    private var passwordRecoveryURLInFlight: URL?
    private var lastHandledPasswordRecoveryURL: URL?

    private(set) var state: AuthState = .loading
    private(set) var isWorking = false
    private(set) var signOutFailure: SignOutFailure?
    private(set) var hasPendingLocalAccountDeletion = false
    private(set) var isPasswordRecoveryPresented = false
    var errorMessage: String?

    init(backend: any AuthBackend, defaults: UserDefaults = .standard) {
        self.backend = backend
        self.defaults = defaults
    }

    func restoreSession() async {
        guard !hasRestored else { return }
        hasRestored = true
        let revision = authenticationRevision

        let cachedAccount = cachedAccount()
        if var cachedAccount {
            cachedAccount.isOffline = true
            state = .authenticated(cachedAccount)
        }

        do {
            let account = try await backend.restoreSession()
            guard revision == authenticationRevision else { return }
            if let account {
                authenticate(account)
            } else {
                clearCachedAccount()
                state = .signedOut
            }
        } catch where error.isConnectivityFailure {
            guard revision == authenticationRevision else { return }
            if cachedAccount == nil {
                state = .signedOut
                errorMessage = "Connect to the internet to sign in for the first time."
            }
        } catch {
            guard revision == authenticationRevision else { return }
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

    func requestPasswordReset(email: String) async -> Bool {
        await perform {
            try await backend.requestPasswordReset(email: email)
            return true
        } ?? false
    }

    func handlePasswordRecoveryURL(_ url: URL) async {
        guard url.scheme == AuthConfiguration.passwordRecoveryURL.scheme,
              url.host == AuthConfiguration.passwordRecoveryURL.host,
              passwordRecoveryURLInFlight == nil,
              lastHandledPasswordRecoveryURL != url
        else {
            return
        }

        authenticationRevision += 1
        passwordRecoveryURLInFlight = url
        defer { passwordRecoveryURLInFlight = nil }

        guard let account = await perform(
            errorMessage: { _ in "That password-reset link is invalid or expired. Request a new one." },
            operation: { try await backend.recoverSession(from: url) }
        ) else { return }

        lastHandledPasswordRecoveryURL = url
        authenticate(account)
        isPasswordRecoveryPresented = true
    }

    func updateRecoveredPassword(_ password: String) async {
        let didUpdate = await perform {
            try await backend.updatePassword(password)
            return true
        } ?? false
        guard didUpdate else { return }
        isPasswordRecoveryPresented = false
    }

    func signOut(pendingChangeCount: Int) async {
        signOutFailure = nil
        guard pendingChangeCount == 0 else {
            signOutFailure = .pendingChanges(pendingChangeCount)
            return
        }

        beginWorking()
        defer { endWorking() }
        do {
            try await backend.signOut()
            clearCachedAccount()
            state = .signedOut
        } catch {
            signOutFailure = .backend(error.localizedDescription)
        }
    }

    func deleteAccount(purgeLocalData: () throws -> Void) async -> Bool {
        beginWorking()
        errorMessage = nil
        defer { endWorking() }

        do {
            if !hasPendingLocalAccountDeletion {
                try await backend.deleteAccount()
                hasPendingLocalAccountDeletion = true
            }
            do {
                try purgeLocalData()
            } catch {
                errorMessage = "Your account was deleted, but local files could not be fully removed: "
                    + error.localizedDescription
                return false
            }
            hasPendingLocalAccountDeletion = false
            clearCachedAccount()
            state = .signedOut
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
        guard let account = await perform(operation: operation) else { return }
        authenticate(account)
    }

    private func perform<Value>(
        errorMessage message: (Error) -> String = { $0.localizedDescription },
        operation: () async throws -> Value
    ) async -> Value? {
        beginWorking()
        errorMessage = nil
        defer { endWorking() }

        do {
            return try await operation()
        } catch {
            errorMessage = message(error)
            return nil
        }
    }

    private func beginWorking() {
        workingOperationCount += 1
        isWorking = true
    }

    private func endWorking() {
        workingOperationCount = max(0, workingOperationCount - 1)
        isWorking = workingOperationCount > 0
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
