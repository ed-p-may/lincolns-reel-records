import SwiftUI

struct DashboardView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SwiftDataProfileRepository.self) private var profileRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catches: [CatchItem] = []
    @State private var heroPhotosByCatch: [UUID: CatchPhotoItem] = [:]
    @State private var now = Date.now
    @State private var loadError: String?
    @State private var greetingName: String?

    let account: AccountSession
    let refreshToken: Int
    let onAddCatch: () -> Void
    let onOpenCatch: (CatchItem) -> Void
    let onOpenLog: () -> Void
    let onOpenSpot: (DashboardSpot) -> Void

    var body: some View {
        let insights = DashboardDerivation.insights(from: catches, now: now, calendar: calendar)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                DashboardHeader(account: account, greetingName: greetingName, now: now, calendar: calendar)
                DashboardHero(insights: insights, onAddCatch: onAddCatch)
                    .padding(.top, 20)
                DashboardStatGrid(insights: insights)
                    .padding(.top, 16)
                recentSection(insights: insights)
                    .padding(.top, 28)
                favoriteSpotsSection(insights: insights)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(ReelTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { reload() }
        .task(id: refreshToken + syncCoordinator.revision) { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
            }
        }
        .alert("Unable to open dashboard", isPresented: errorBinding) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private func recentSection(insights: DashboardInsights) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardSectionHeader(title: "Recent catches", actionTitle: "See all", action: onOpenLog)

            if insights.recentCatches.isEmpty {
                DashboardEmptyCard(
                    icon: "photo.on.rectangle.angled",
                    title: "Your first catch will appear here",
                    message: "Log it now—even if you are offline."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(insights.recentCatches.enumerated()), id: \.element.id) { index, catchItem in
                            Button {
                                onOpenCatch(catchItem)
                            } label: {
                                DashboardRecentCatchCard(
                                    catchItem: catchItem,
                                    heroPhotoURL: heroPhotoURL(catchID: catchItem.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard.recent.\(index)")
                        }
                    }
                }
            }
        }
    }

    private func favoriteSpotsSection(insights: DashboardInsights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: "Favorite spots")

            if insights.favoriteSpots.isEmpty {
                DashboardEmptyCard(
                    icon: "location.slash",
                    title: "No named spots yet",
                    message: "Add a spot name to a catch to build this list."
                )
            } else {
                ForEach(Array(insights.favoriteSpots.prefix(3))) { spot in
                    Button {
                        onOpenSpot(spot)
                    } label: {
                        DashboardSpotRow(spot: spot)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.spot.\(spot.id)")
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: {
                if !$0 {
                    loadError = nil
                }
            }
        )
    }

    private func reload() {
        do {
            let loadedCatches = try repository.list(ownerID: account.ownerID)
            now = .now
            let recentIDs = DashboardDerivation.insights(from: loadedCatches, now: now, calendar: calendar)
                .recentCatches.map(\.id)
            catches = loadedCatches
            let profile = try profileRepository.profile(account: account)
            greetingName = profile.displayName.split(separator: " ").first.map(String.init)
            heroPhotosByCatch = try photoRepository.heroPhotos(catchIDs: recentIDs, ownerID: account.ownerID)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func heroPhotoURL(catchID: UUID) -> URL? {
        heroPhotosByCatch[catchID].flatMap(photoRepository.fileURL(for:))
    }
}

private struct DashboardHeader: View {
    let account: AccountSession
    let greetingName: String?
    let now: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(ReelTheme.accent)
            Text("\(greeting), \(greetingName ?? account.username)")
                .reelDisplayFont(26, weight: .heavy)
                .foregroundStyle(ReelTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("dashboard.greeting")
        }
    }

    private var greeting: String {
        switch calendar.component(.hour, from: now) {
        case 5 ..< 12: "Morning"
        case 12 ..< 17: "Afternoon"
        default: "Evening"
        }
    }
}

private struct DashboardHero: View {
    let insights: DashboardInsights
    let onAddCatch: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color(red: 20 / 255, green: 51 / 255, blue: 36 / 255), ReelTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "fish.fill")
                .font(.system(size: 140, weight: .black))
                .foregroundStyle(ReelTheme.accent.opacity(0.07))
                .offset(x: 34, y: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("Total catches logged")
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.secondaryText)
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(insights.totalCatches.formatted())
                        .reelDisplayFont(58, weight: .black)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("dashboard.total")
                    Text("+\(insights.catchesThisWeek) this week")
                        .font(ReelFont.body(.caption, weight: .bold))
                        .foregroundStyle(ReelTheme.accentHighlight)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ReelTheme.accent.opacity(0.12), in: Capsule())
                        .accessibilityIdentifier("dashboard.week")
                }
                Button(action: onAddCatch) {
                    Label("Log a Catch", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
                .reelDisplayFont(15, weight: .heavy)
                .foregroundStyle(ReelTheme.accentInk)
                .background(ReelTheme.accent, in: RoundedRectangle(cornerRadius: 15))
                .padding(.top, 16)
                .accessibilityIdentifier("dashboard.add")
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(ReelTheme.accent.opacity(0.22)) }
    }
}

private struct DashboardStatGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let insights: DashboardInsights

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            DashboardStatTile(
                icon: "trophy.fill",
                value: insights.biggestCatch?.weight.map(CatchFormatting.weight) ?? "—",
                detail: insights.biggestCatch.map { "Biggest · \($0.species)" } ?? "Biggest · Not measured"
            )
            DashboardStatTile(
                icon: "star.fill",
                value: insights.topSpecies?.label ?? "—",
                detail: insights.topSpecies.map { "Top species · \($0.count)" } ?? "Top species · No catches"
            )
            DashboardStatTile(
                icon: "location.fill",
                value: insights.favoriteSpot?.name ?? "—",
                detail: insights.favoriteSpot.map { "Favorite · \($0.count)" } ?? "Favorite · No named spots"
            )
            DashboardStatTile(
                icon: "water.waves",
                value: insights.speciesThisYear.formatted(),
                detail: "Species this year"
            )
        }
        .accessibilityIdentifier("dashboard.stats")
    }

    private var columns: [GridItem] {
        dynamicTypeSize >= .xxxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    }
}

private struct DashboardStatTile: View {
    let icon: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ReelTheme.accentHighlight)
                .frame(width: 34, height: 34)
                .background(ReelTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            Text(value)
                .reelDisplayFont(19, weight: .heavy)
                .foregroundStyle(ReelTheme.primaryText)
            Text(detail)
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(15)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .reelDisplayFont(18)
                .foregroundStyle(ReelTheme.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(ReelFont.body(.caption, weight: .bold))
                    .foregroundStyle(ReelTheme.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("dashboard.see-all")
            }
        }
    }
}

private struct DashboardRecentCatchCard: View {
    let catchItem: CatchItem
    let heroPhotoURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LocalPhotoImage(
                    url: heroPhotoURL,
                    maximumPixelSize: 420,
                    contentMode: .fill,
                    placeholder: CatchPhotoPlaceholder(species: catchItem.species)
                )
                .frame(width: 166, height: 116)
                .clipped()
                if let weight = catchItem.weight {
                    Text(CatchFormatting.weight(weight))
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(ReelTheme.page, in: RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(catchItem.species)
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(1)
                Label(catchItem.location ?? "Spot not recorded", systemImage: "location.fill")
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.tertiaryText)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: 166)
        .background(ReelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([catchItem.species, catchItem.weight.map(CatchFormatting.weight), catchItem.location]
            .compactMap(\.self).joined(separator: ", "))
        .accessibilityHint("Opens catch detail")
    }
}

private struct DashboardSpotRow: View {
    let spot: DashboardSpot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ReelTheme.accentHighlight)
                .frame(width: 42, height: 42)
                .background(ReelTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(spot.name)
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                    .lineLimit(2)
                Text("\(spot.count) catch\(spot.count == 1 ? "" : "es") · \(bestLabel)")
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.tertiaryText)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(ReelTheme.tertiaryText)
        }
        .padding(14)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.border) }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this spot on the catch map")
    }

    private var bestLabel: String {
        guard let catchItem = spot.bestCatch else { return "best fish not measured" }
        if let weight = catchItem.weight {
            return "best \(CatchFormatting.weight(weight)) \(catchItem.species)"
        }
        if let length = catchItem.length {
            return "best \(CatchFormatting.length(length)) \(catchItem.species)"
        }
        return "best fish not measured"
    }
}

private struct DashboardEmptyCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(ReelTheme.accentHighlight)
                .frame(width: 40, height: 40)
                .background(ReelTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ReelFont.body(.subheadline, weight: .bold))
                    .foregroundStyle(ReelTheme.primaryText)
                Text(message)
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.border) }
    }
}
