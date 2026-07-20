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

enum AppSheet: Identifiable {
    case addCatch
    case catchDetail(CatchItem)

    var id: String {
        switch self {
        case .addCatch:
            "add-catch"
        case let .catchDetail(catchItem):
            "catch-detail-\(catchItem.id.uuidString)"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var presentedSheet: AppSheet?
    var addReturnTab: AppTab = .home
    var mapFocusCatchID: UUID?
    var mapFocusSpotName: String?
    var mapFocusRevision = 0

    func select(_ tab: AppTab) {
        if tab == .add {
            presentAddCatch(returningTo: selectedTab)
        } else {
            if tab == .map {
                mapFocusCatchID = nil
                mapFocusSpotName = nil
            }
            selectedTab = tab
        }
    }

    func presentAddCatch(returningTo tab: AppTab) {
        addReturnTab = tab
        presentedSheet = .addCatch
    }

    func showOnMap(_ catchItem: CatchItem) {
        showOnMap(catchID: catchItem.id, spotName: catchItem.location)
    }

    func showSpotOnMap(_ spot: DashboardSpot) {
        showOnMap(catchID: spot.mapFocusCatchID, spotName: spot.name)
    }

    private func showOnMap(catchID: UUID?, spotName: String?) {
        mapFocusCatchID = catchID
        mapFocusSpotName = spotName
        mapFocusRevision += 1
        presentedSheet = nil
        selectedTab = .map
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
            tab(.home) {
                DashboardView(
                    account: account,
                    refreshToken: logRevision,
                    onAddCatch: { router.presentAddCatch(returningTo: .home) },
                    onOpenCatch: { router.presentedSheet = .catchDetail($0) },
                    onOpenLog: { router.selectedTab = .log },
                    onOpenSpot: { router.showSpotOnMap($0) }
                )
            }
            tab(.log) {
                LogbookView(
                    ownerID: account.ownerID,
                    refreshToken: logRevision,
                    onAddCatch: { router.presentAddCatch(returningTo: .log) },
                    onOpenCatch: { router.presentedSheet = .catchDetail($0) }
                )
            }
            tab(.add) { Color.clear }
            tab(.map) {
                CatchMapView(
                    ownerID: account.ownerID,
                    refreshToken: logRevision,
                    focusCatchID: router.mapFocusCatchID,
                    focusSpotName: router.mapFocusSpotName,
                    focusRevision: router.mapFocusRevision,
                    onOpenCatch: { router.presentedSheet = .catchDetail($0) }
                )
            }
            tab(.profile) { ProfileView(account: account) }
        }
        .tint(ReelTheme.accent)
        .sheet(item: $router.presentedSheet) { destination in
            switch destination {
            case .addCatch:
                AddCatchView(ownerID: account.ownerID) {
                    logRevision += 1
                    router.selectedTab = router.addReturnTab
                }
            case let .catchDetail(catchItem):
                CatchDetailView(
                    catchItem: catchItem,
                    onChanged: { logRevision += 1 },
                    onShowOnMap: { router.showOnMap($0) }
                )
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
