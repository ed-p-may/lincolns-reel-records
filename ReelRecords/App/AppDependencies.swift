import Foundation
import Supabase
import SwiftData

@MainActor
final class AppDependencies {
    private static let uiTestOwnerID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!

    let authService: AuthService
    let catchRepository: SwiftDataCatchRepository
    let modelContainer: ModelContainer
    let syncCoordinator: SyncCoordinator

    init(isUITesting: Bool = AppDependencies.isRunningTests) {
        do {
            let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            let container = try ModelContainer(
                for: CatchRecord.self,
                OutboxOperation.self,
                configurations: modelConfiguration
            )
            let repository = SwiftDataCatchRepository(modelContext: container.mainContext)

            if isUITesting, ProcessInfo.processInfo.arguments.contains("--ui-testing-logbook") {
                try Self.seedLogbook(repository: repository)
            }

            let authBackend: any AuthBackend
            let remoteStore: any CatchRemoteStore

            if isUITesting {
                let account = AccountSession(
                    ownerID: Self.uiTestOwnerID,
                    email: "ui-test@example.com",
                    username: "ui_test",
                    isOffline: false
                )
                authBackend = MockAuthBackend(account: account)
                remoteStore = InMemoryCatchRemoteStore()
            } else {
                let configuration = AppConfiguration.live()
                let client = SupabaseClient(
                    supabaseURL: configuration.supabaseURL,
                    supabaseKey: configuration.supabasePublishableKey
                )
                authBackend = SupabaseAuthBackend(client: client)
                remoteStore = SupabaseCatchRemoteStore(client: client)
            }

            modelContainer = container
            catchRepository = repository
            authService = AuthService(backend: authBackend)
            syncCoordinator = SyncCoordinator(repository: repository, remoteStore: remoteStore)
        } catch {
            fatalError("Unable to create the local data store: \(error)")
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func seedLogbook(repository: SwiftDataCatchRepository) throws {
        _ = try repository.create(NewCatch(
            ownerID: uiTestOwnerID,
            values: CatchValues(
                species: "Largemouth Bass With An Exceptionally Long Display Name",
                weight: 2.25,
                length: 18.5,
                caughtAt: Date(timeIntervalSince1970: 1_753_000_000),
                location: "Stockbridge Bowl North Shore By The Old Stone Landing",
                lureText: "Green pumpkin jig",
                rodReel: "7-foot medium spinning rod",
                notes: "Calm morning with a long field note to verify that the complete story remains readable.",
                released: true
            )
        ))
        _ = try repository.create(NewCatch(
            ownerID: uiTestOwnerID,
            values: CatchValues(
                species: "Rainbow Trout",
                weight: 6.5,
                length: 24,
                caughtAt: Date(timeIntervalSince1970: 1_752_000_000),
                location: "Lake Mansfield",
                lureText: "Café spoon",
                rodReel: nil,
                notes: "Caught beside the old dock.",
                released: false
            )
        ))
    }
}
