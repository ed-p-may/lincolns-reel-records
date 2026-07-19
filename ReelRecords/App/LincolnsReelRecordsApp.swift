import SwiftData
import SwiftUI

@main
struct LincolnsReelRecordsApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies.authService)
                .environment(dependencies.catchRepository)
                .environment(dependencies.syncCoordinator)
                .modelContainer(dependencies.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
