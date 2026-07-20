import Foundation

struct DashboardLabelStat: Equatable, Sendable {
    let label: String
    let count: Int
}

struct DashboardSpot: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let count: Int
    let bestCatch: CatchItem?
    let mapFocusCatchID: UUID?
}

struct DashboardInsights: Equatable, Sendable {
    let totalCatches: Int
    let catchesThisWeek: Int
    let biggestCatch: CatchItem?
    let topSpecies: DashboardLabelStat?
    let speciesThisYear: Int
    let recentCatches: [CatchItem]
    let favoriteSpots: [DashboardSpot]

    var favoriteSpot: DashboardSpot? {
        favoriteSpots.first
    }
}

struct DashboardRecordSummary: Equatable, Sendable {
    let totalCatches: Int
    let biggestCatch: CatchItem?
    let speciesBreakdown: [DashboardLabelStat]
}

enum DashboardDerivation {
    static func insights(
        from catches: [CatchItem],
        now: Date = .now,
        calendar: Calendar = .current,
        recentLimit: Int = 4
    ) -> DashboardInsights {
        let visible = catches.filter { $0.deletedAt == nil }
        let recent = visible.sorted(by: CatchDiscovery.recentPrecedes)
        let recordSummary = summary(fromVisible: visible)
        let spots = spotGroups(in: visible)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisYear = calendar.dateInterval(of: .year, for: now)

        return DashboardInsights(
            totalCatches: recordSummary.totalCatches,
            catchesThisWeek: count(in: visible, interval: thisWeek, through: now),
            biggestCatch: recordSummary.biggestCatch,
            topSpecies: recordSummary.speciesBreakdown.first,
            speciesThisYear: Set<String>(visible.compactMap { catchItem in
                guard contains(catchItem.caughtAt, in: thisYear, through: now) else { return nil }
                return CatchDiscovery.normalized(catchItem.species.trimmed)
            }).count,
            recentCatches: Array(recent.prefix(recentLimit)),
            favoriteSpots: spots
        )
    }

    static func recordSummary(from catches: [CatchItem]) -> DashboardRecordSummary {
        summary(fromVisible: catches.filter { $0.deletedAt == nil })
    }
}

private extension DashboardDerivation {
    struct CatchGroup {
        let key: String
        let label: String
        let catches: [CatchItem]
    }

    struct RankedSpot {
        let spot: DashboardSpot
        let latestCatch: CatchItem
    }

    static func groups(
        in catches: [CatchItem],
        label: KeyPath<CatchItem, String>
    ) -> [CatchGroup] {
        Dictionary(grouping: catches) { CatchDiscovery.normalized($0[keyPath: label].trimmed) }
            .map { key, matches in
                let ordered = matches.sorted(by: CatchDiscovery.recentPrecedes)
                return CatchGroup(key: key, label: ordered[0][keyPath: label].trimmed, catches: ordered)
            }
            .sorted(by: groupPrecedes)
    }

    static func summary(fromVisible catches: [CatchItem]) -> DashboardRecordSummary {
        let species = groups(in: catches, label: \CatchItem.species).map {
            DashboardLabelStat(label: $0.label, count: $0.catches.count)
        }
        return DashboardRecordSummary(
            totalCatches: catches.count,
            biggestCatch: catches.filter { $0.weight != nil }.sorted(by: heaviestPrecedes).first,
            speciesBreakdown: species
        )
    }

    static func spotGroups(in catches: [CatchItem]) -> [DashboardSpot] {
        Dictionary(grouping: catches.compactMap { catchItem -> (String, CatchItem)? in
            guard let name = catchItem.location?.trimmed, !name.isEmpty else { return nil }
            guard let key = SpotSummary.normalizedName(name) else { return nil }
            return (key, catchItem)
        }, by: { $0.0 })
            .map { key, pairs in
                let ordered = pairs.map(\.1).sorted(by: CatchDiscovery.recentPrecedes)
                let measuredByWeight = ordered.filter { $0.weight != nil }.sorted(by: heaviestPrecedes)
                let measuredByLength = ordered.filter { $0.length != nil }.sorted(by: longestPrecedes)
                return RankedSpot(
                    spot: DashboardSpot(
                        id: key,
                        name: ordered[0].location?.trimmed ?? "Unnamed spot",
                        count: ordered.count,
                        bestCatch: measuredByWeight.first ?? measuredByLength.first,
                        mapFocusCatchID: ordered.first(where: { $0.coordinate != nil })?.id
                    ),
                    latestCatch: ordered[0]
                )
            }
            .sorted { first, second in
                if first.spot.count != second.spot.count {
                    return first.spot.count > second.spot.count
                }
                if first.latestCatch.caughtAt != second.latestCatch.caughtAt {
                    return first.latestCatch.caughtAt > second.latestCatch.caughtAt
                }
                return CatchDiscovery.alphabeticallyPrecedes(first.spot.name, second.spot.name)
            }
            .map(\.spot)
    }

    static func groupPrecedes(_ first: CatchGroup, _ second: CatchGroup) -> Bool {
        if first.catches.count != second.catches.count {
            return first.catches.count > second.catches.count
        }
        if first.catches[0].caughtAt != second.catches[0].caughtAt {
            return first.catches[0].caughtAt > second.catches[0].caughtAt
        }
        if first.label != second.label {
            return CatchDiscovery.alphabeticallyPrecedes(first.label, second.label)
        }
        return first.key < second.key
    }

    static func count(in catches: [CatchItem], interval: DateInterval?, through now: Date) -> Int {
        catches.count { contains($0.caughtAt, in: interval, through: now) }
    }

    static func contains(_ date: Date, in interval: DateInterval?, through now: Date) -> Bool {
        guard let interval else { return false }
        return date <= now && interval.contains(date)
    }

    static func heaviestPrecedes(_ first: CatchItem, _ second: CatchItem) -> Bool {
        CatchDiscovery.measurementPrecedes(first.weight, second.weight, first: first, second: second)
    }

    static func longestPrecedes(_ first: CatchItem, _ second: CatchItem) -> Bool {
        CatchDiscovery.measurementPrecedes(first.length, second.length, first: first, second: second)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
