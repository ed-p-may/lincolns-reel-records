import Foundation
import Supabase
import SwiftData

@MainActor
final class AppDependencies {
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

            let authBackend: any AuthBackend
            let remoteStore: any CatchRemoteStore

            if isUITesting {
                let account = AccountSession(
                    ownerID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
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
}
