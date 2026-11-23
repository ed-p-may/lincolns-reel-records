import SafariServices
import SwiftUI

struct WaterBodyInfoSheet: View {
    let selection: WaterBodySelection
    let localHistory: LocalWaterHistory
    let info: WaterBodyInfo?
    let isLoading: Bool
    let isOfflineUnavailable: Bool
    let onRefresh: () -> Void
    let onOpenCatch: (CatchItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedDetent: PresentationDetent = .fraction(0.28)
    @State private var activeSafariURL: SafariDestination?
    @State private var isRefreshCoolingDown = false
    @State private var refreshCooldownTask: Task<Void, Never>?

    private static let refreshCooldown: TimeInterval = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WaterBodyHeaderView(
                    selection: selection,
                    localHistory: localHistory,
                    info: info,
                    onDismiss: onDismiss
                )

                if localHistory.catchCount > 0 {
                    LocalWaterHistorySection(
                        history: localHistory,
                        onOpenCatch: onOpenCatch
                    )
                }

                statusSection

                if let info {
                    if let overview = info.overview, !overview.isEmpty {
                        WaterBodyOverviewSection(
                            overview: overview,
                            wikipediaURL: info.wikipediaURL,
                            onOpenURL: openInSafari
                        )
                    }

                    if let gauge = info.riverGauge, gauge.hasAnyMeasurement {
                        RiverGaugeSection(gauge: gauge)
                    }

                    if !info.accessPoints.isEmpty {
                        WaterBodyAccessSection(accessPoints: info.accessPoints)
                    }

                    if !info.species.isEmpty {
                        WaterBodySpeciesSection(species: info.species)
                    }

                    if !info.photos.isEmpty {
                        WaterBodyPhotosSection(
                            photos: info.photos,
                            onOpenURL: openInSafari
                        )
                    }
                }

                WaterBodyExploreLinksSection(
                    links: WaterBodyQuickLink.defaultLinks(for: selection),
                    onOpenURL: openInSafari
                )

                footerSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(ReelTheme.background)
        .presentationDetents([.fraction(0.28), .medium, .large], selection: $selectedDetent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(ReelTheme.background)
        .sheet(item: $activeSafariURL) { destination in
            SafariWebView(url: destination.url)
                .ignoresSafeArea()
        }
        .onChange(of: selection.id) { _, _ in
            refreshCooldownTask?.cancel()
            isRefreshCoolingDown = false
        }
        .onDisappear {
            refreshCooldownTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("water-sheet.container")
    }

    @ViewBuilder
    private var statusSection: some View {
        if isLoading, info == nil {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(ReelTheme.accent)
                Text("Loading public fishing info…")
                    .font(ReelFont.body(.subheadline))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("water-sheet.loading")
        } else if isOfflineUnavailable, info == nil {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(ReelTheme.secondaryText)
                Text("Connect to load public fishing info. Your local catch history stays available offline.")
                    .font(ReelFont.body(.subheadline))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("water-sheet.offline")
        } else if let info, !info.hasPublicContent {
            VStack(alignment: .leading, spacing: 6) {
                Text("Limited public fishing info found for \(selection.name)")
                    .font(ReelFont.body(.subheadline, weight: .semibold))
                    .foregroundStyle(ReelTheme.primaryText)
                Text("Try the public search links below to check local reports, species, and access.")
                    .font(ReelFont.body(.caption))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("water-sheet.sparse")
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let info {
                    if info.isFromOfflineCache {
                        Label("Saved offline", systemImage: "icloud.slash")
                            .font(ReelFont.metadata(.caption2, weight: .semibold))
                            .foregroundStyle(ReelTheme.accessPin)
                            .accessibilityIdentifier("water-sheet.saved-offline")
                    } else {
                        Text("Updated \(info.fetchedAt.formatted(.relative(presentation: .named)))")
                            .font(ReelFont.metadata(.caption2))
                            .foregroundStyle(ReelTheme.tertiaryText)
                    }
                }
                Spacer()
                Button {
                    guard canRefresh else { return }
                    startRefreshCooldown()
                    onRefresh()
                } label: {
                    Label(isLoading ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                        .font(ReelFont.metadata(.caption2, weight: .semibold))
                        .foregroundStyle(canRefresh ? ReelTheme.accent : ReelTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .disabled(!canRefresh)
                .accessibilityIdentifier("water-sheet.refresh")
            }

            Text("Publicly sourced info — verify local fishing regulations and access rules.")
                .font(ReelFont.body(.caption2))
                .foregroundStyle(ReelTheme.tertiaryText)
        }
        .padding(.top, 4)
    }

    private var canRefresh: Bool {
        !isLoading && !isRefreshCoolingDown
    }

    private func startRefreshCooldown() {
        isRefreshCoolingDown = true
        refreshCooldownTask?.cancel()
        refreshCooldownTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.refreshCooldown))
            guard !Task.isCancelled else { return }
            isRefreshCoolingDown = false
        }
    }

    private func openInSafari(_ url: URL) {
        activeSafariURL = SafariDestination(url: url)
    }
}

private struct SafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = UIColor(ReelTheme.background)
        controller.preferredControlTintColor = UIColor(ReelTheme.accent)
        return controller
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
