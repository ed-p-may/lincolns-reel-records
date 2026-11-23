import Foundation

struct TackleTypeSection: Identifiable, Equatable, Sendable {
    let type: TackleItemType
    let items: [TackleItem]

    var id: TackleItemType {
        type
    }
}

enum TackleDiscovery {
    static func results(
        in items: [TackleItem],
        query: String,
        type: TackleItemType?
    ) -> [TackleItem] {
        let normalizedQuery = CatchDiscovery.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return items.filter { item in
            (type == nil || item.type == type)
                && matches(item, normalizedQuery: normalizedQuery)
        }
        .sorted(by: alphabeticallyPrecedes)
    }

    static func recentlyUsed(
        from items: [TackleItem],
        catches: [CatchItem],
        limit: Int = 5
    ) -> [TackleItem] {
        guard limit > 0 else { return [] }
        let selectableByID = Dictionary(
            uniqueKeysWithValues: items.filter(\.isSelectable).map { ($0.id, $0) }
        )
        guard !selectableByID.isEmpty else { return [] }

        let visibleCatches = catches
            .filter { $0.deletedAt == nil }
            .sorted(by: CatchDiscovery.recentPrecedes)

        var seen: Set<UUID> = []
        var recent: [TackleItem] = []
        recent.reserveCapacity(limit)

        for catchItem in visibleCatches {
            guard let itemID = catchItem.tackleItemID,
                  !seen.contains(itemID),
                  let item = selectableByID[itemID]
            else { continue }
            seen.insert(itemID)
            recent.append(item)
            if recent.count == limit {
                break
            }
        }
        return recent
    }

    static func inlineStripItems(
        from items: [TackleItem],
        recentItems: [TackleItem],
        limit: Int = 5
    ) -> (items: [TackleItem], isRecent: Bool) {
        guard limit > 0 else { return ([], false) }
        let selectableRecent = recentItems.filter(\.isSelectable)
        if !selectableRecent.isEmpty {
            return (Array(selectableRecent.prefix(limit)), true)
        }
        let fallback = items
            .filter(\.isSelectable)
            .sorted(by: alphabeticallyPrecedes)
            .prefix(limit)
        return (Array(fallback), false)
    }

    static func sectionsByType(
        in items: [TackleItem],
        query: String = "",
        type: TackleItemType? = nil
    ) -> [TackleTypeSection] {
        let filtered = results(in: items, query: query, type: type)
        let grouped = Dictionary(grouping: filtered, by: \.type)
        return TackleItemType.allCases.compactMap { itemType in
            guard let sectionItems = grouped[itemType], !sectionItems.isEmpty else { return nil }
            return TackleTypeSection(type: itemType, items: sectionItems)
        }
    }

    static func availableTypes(in items: [TackleItem]) -> [TackleItemType] {
        let present = Set(items.map(\.type))
        return TackleItemType.allCases.filter { present.contains($0) }
    }

    static func alphabeticallyPrecedes(_ first: TackleItem, _ second: TackleItem) -> Bool {
        if CatchDiscovery.normalized(first.name) != CatchDiscovery.normalized(second.name) {
            return CatchDiscovery.alphabeticallyPrecedes(first.name, second.name)
        }
        return first.id.uuidString < second.id.uuidString
    }

    private static func matches(_ item: TackleItem, normalizedQuery: String) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }
        let searchableText = [item.name, item.brand, item.color]
            .compactMap(\.self)
            .joined(separator: " ")
        return CatchDiscovery.normalized(searchableText).contains(normalizedQuery)
    }
}
