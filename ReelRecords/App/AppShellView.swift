import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case log
    case add
    case map
    case profile

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .home: "Home"
        case .log: "Log"
        case .add: "Add"
        case .map: "Map"
        case .profile: "You"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .log: "book.closed.fill"
        case .add: "plus.circle.fill"
        case .map: "map.fill"
        case .profile: "person.fill"
        }
    }
}

enum AppSheet: String, Identifiable {
    case addCatch

    var id: String {
        rawValue
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .log
    var presentedSheet: AppSheet?

    func select(_ tab: AppTab) {
        if tab == .add {
            presentedSheet = .addCatch
        } else {
            selectedTab = tab
        }
    }
}

private struct SyncRequest: Equatable {
    let ownerID: UUID
    let isOffline: Bool
}

struct AppShellView: View {
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var router = AppRouter()
    @State private var logRevision = 0

    let account: AccountSession

    var body: some View {
        @Bindable var router = router

        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.select($0) }
        )) {
            tab(.home) { PlaceholderTabView(title: "Home", message: "Dashboard arrives in Phase 07.") }
            tab(.log) {
                LogbookView(
                    ownerID: account.ownerID,
                    refreshToken: logRevision,
                    onAddCatch: { router.presentedSheet = .addCatch }
                )
            }
            tab(.add) { Color.clear }
            tab(.map) { PlaceholderTabView(title: "Map", message: "Catch locations arrive in Phase 05.") }
            tab(.profile) { ProfilePlaceholderView(account: account) }
        }
        .tint(ReelTheme.accent)
        .sheet(item: $router.presentedSheet) { destination in
            switch destination {
            case .addCatch:
                AddCatchView(ownerID: account.ownerID) {
                    logRevision += 1
                    router.selectedTab = .log
                }
            }
        }
        .task(id: SyncRequest(ownerID: account.ownerID, isOffline: account.isOffline)) {
            guard !account.isOffline else { return }
            await syncCoordinator.sync(ownerID: account.ownerID)
        }
    }

    private func tab(_ appTab: AppTab, @ViewBuilder content: () -> some View) -> some View {
        NavigationStack {
            content()
        }
        .tabItem { Label(appTab.title, systemImage: appTab.systemImage) }
        .tag(appTab)
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "fish.fill", description: Text(message))
            .foregroundStyle(ReelTheme.primaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReelTheme.background)
            .navigationTitle(title)
    }
}
