import Foundation

struct AccountSession: Codable, Equatable, Sendable {
    let ownerID: UUID
    let email: String
    let username: String
    var isOffline: Bool
}

enum AuthState: Equatable {
    case loading
    case signedOut
    case authenticated(AccountSession)
}

enum AuthServiceError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            "No authenticated session was returned."
        }
    }
}

enum SignOutFailure: Equatable {
    case pendingCatches(Int)
    case localStore(String)
    case backend(String)

    var message: String {
        switch self {
        case let .pendingCatches(count):
            "Connect and sync \(count) pending catch\(count == 1 ? "" : "es") before signing out."
        case let .localStore(message), let .backend(message):
            message
        }
    }

    var canRetrySync: Bool {
        if case .pendingCatches = self {
            return true
        }
        return false
    }
}

extension Error {
    var isConnectivityFailure: Bool {
        let error = self as NSError
        if error.domain == NSURLErrorDomain {
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorTimedOut
            ].contains(error.code)
        }
        return false
    }
}
