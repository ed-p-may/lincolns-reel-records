import Foundation
import Supabase
import SwiftData
import UIKit

private struct AppServices {
    let authBackend: any AuthBackend
    let catchRemoteStore: any CatchRemoteStore
    let photoRemoteStore: any CatchPhotoRemoteStore
}

@MainActor
final class AppDependencies {
    private static let uiTestOwnerID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!

    let authService: AuthService
    let catchRepository: SwiftDataCatchRepository
    let catchPhotoRepository: SwiftDataCatchPhotoRepository
    let modelContainer: ModelContainer
    let syncCoordinator: SyncCoordinator

    init(isUITesting: Bool = AppDependencies.isRunningTests) {
        do {
            let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            let container = try ModelContainer(
                for: CatchRecord.self,
                OutboxOperation.self,
                CatchPhotoRecord.self,
                PhotoOutboxOperation.self,
                configurations: modelConfiguration
            )
            let repository = SwiftDataCatchRepository(modelContext: container.mainContext)
            let photoRepository = try SwiftDataCatchPhotoRepository(
                modelContext: container.mainContext,
                fileStore: Self.makePhotoFileStore(isUITesting: isUITesting)
            )

            if isUITesting, ProcessInfo.processInfo.arguments.contains("--ui-testing-logbook") {
                try Self.seedLogbook(repository: repository, photoRepository: photoRepository)
            }

            let services = Self.makeServices(isUITesting: isUITesting)

            modelContainer = container
            catchRepository = repository
            catchPhotoRepository = photoRepository
            authService = AuthService(backend: services.authBackend)
            syncCoordinator = SyncCoordinator(
                repository: repository,
                remoteStore: services.catchRemoteStore,
                photoSync: PhotoSyncDependencies(
                    repository: photoRepository,
                    remoteStore: services.photoRemoteStore
                )
            )
        } catch {
            fatalError("Unable to create the local data store: \(error)")
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func makePhotoFileStore(isUITesting: Bool) throws -> PhotoFileStore {
        let testRoot = isUITesting
            ? FileManager.default.temporaryDirectory
            .appendingPathComponent("ReelRecords-UITests-\(ProcessInfo.processInfo.processIdentifier)")
            : nil
        return try PhotoFileStore(rootURL: testRoot)
    }

    private static func makeServices(isUITesting: Bool) -> AppServices {
        if isUITesting {
            let account = AccountSession(
                ownerID: uiTestOwnerID,
                email: "ui-test@example.com",
                username: "ui_test",
                isOffline: false
            )
            return AppServices(
                authBackend: MockAuthBackend(account: account),
                catchRemoteStore: InMemoryCatchRemoteStore(),
                photoRemoteStore: InMemoryCatchPhotoRemoteStore()
            )
        }
        let configuration = AppConfiguration.live()
        let client = SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.supabasePublishableKey
        )
        return AppServices(
            authBackend: SupabaseAuthBackend(client: client),
            catchRemoteStore: SupabaseCatchRemoteStore(client: client),
            photoRemoteStore: SupabaseCatchPhotoRemoteStore(client: client)
        )
    }

    private static func seedLogbook(
        repository: SwiftDataCatchRepository,
        photoRepository: SwiftDataCatchPhotoRepository
    ) throws {
        let bass = try repository.create(NewCatch(
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
        try seedPhotos(catchID: bass.id, repository: photoRepository)
    }

    private static func seedPhotos(catchID: UUID, repository: SwiftDataCatchPhotoRepository) throws {
        let sessionID = UUID()
        let green = try repository.stage(data: testImageData(color: .systemGreen), sessionID: sessionID)
        let blue = try repository.stage(data: testImageData(color: .systemBlue), sessionID: sessionID)
        try repository.saveOrder(
            catchID: catchID,
            ownerID: uiTestOwnerID,
            orderedIDs: [green.id, blue.id],
            drafts: [green, blue]
        )
    }

    private static func testImageData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900))
        let image = renderer.image { context in
            color.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            let fishFrame = CGRect(x: 420, y: 270, width: 360, height: 360)
            UIImage(systemName: "fish.fill")?.withTintColor(.white).draw(in: fishFrame)
        }
        return image.jpegData(compressionQuality: 0.9)!
    }
}
