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
                .environment(dependencies.catchPhotoRepository)
                .environment(dependencies.tackleRepository)
                .environment(dependencies.locationService)
                .environment(dependencies.syncCoordinator)
                .environment(\.weatherSuggestionProvider, dependencies.weatherSuggestionProvider)
                .modelContainer(dependencies.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
