import Foundation

enum CatchSort: String, CaseIterable, Identifiable, Sendable {
    case recent
    case heaviest
    case longest

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }
}

enum CatchDiscovery {
    private static let comparisonLocale = Locale(identifier: "en_US_POSIX")
    private static let comparisonOptions: String.CompareOptions = [
        .caseInsensitive,
        .diacriticInsensitive,
        .widthInsensitive
    ]

    static func species(in catches: [CatchItem]) -> [String] {
        var displayValueByKey: [String: String] = [:]
        for catchItem in catches {
            let key = normalized(catchItem.species)
            if let existing = displayValueByKey[key] {
                displayValueByKey[key] = min(existing, catchItem.species)
            } else {
                displayValueByKey[key] = catchItem.species
            }
        }
        return displayValueByKey.values.sorted(by: alphabeticallyPrecedes)
    }

    static func results(
        in catches: [CatchItem],
        query: String,
        species: String?,
        sort: CatchSort
    ) -> [CatchItem] {
        let query = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let species = species.map(normalized)

        return catches
            .filter { catchItem in
                matches(catchItem, query: query) && matches(catchItem, species: species)
            }
            .sorted { first, second in
                precedes(first, second, sort: sort)
            }
    }

    private static func matches(_ catchItem: CatchItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let searchableText = [
            catchItem.species,
            catchItem.location,
            catchItem.lureText,
            catchItem.notes
        ]
        .compactMap(\.self)
        .joined(separator: " ")
        return normalized(searchableText).contains(query)
    }

    private static func matches(_ catchItem: CatchItem, species: String?) -> Bool {
        guard let species else { return true }
        return normalized(catchItem.species) == species
    }

    private static func precedes(_ first: CatchItem, _ second: CatchItem, sort: CatchSort) -> Bool {
        switch sort {
        case .recent:
            recentPrecedes(first, second)
        case .heaviest:
            measurementPrecedes(first.weight, second.weight, first: first, second: second)
        case .longest:
            measurementPrecedes(first.length, second.length, first: first, second: second)
        }
    }

    private static func measurementPrecedes(
        _ firstValue: Double?,
        _ secondValue: Double?,
        first: CatchItem,
        second: CatchItem
    ) -> Bool {
        switch (firstValue, secondValue) {
        case let (firstValue?, secondValue?) where firstValue != secondValue:
            firstValue > secondValue
        case (_?, nil):
            true
        case (nil, _?):
            false
        default:
            recentPrecedes(first, second)
        }
    }

    private static func recentPrecedes(_ first: CatchItem, _ second: CatchItem) -> Bool {
        if first.caughtAt != second.caughtAt {
            return first.caughtAt > second.caughtAt
        }
        if first.createdAt != second.createdAt {
            return first.createdAt > second.createdAt
        }
        return first.id.uuidString < second.id.uuidString
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: comparisonOptions, locale: comparisonLocale).lowercased()
    }

    private static func alphabeticallyPrecedes(_ first: String, _ second: String) -> Bool {
        first.compare(
            second,
            options: comparisonOptions,
            range: nil,
            locale: comparisonLocale
        ) == .orderedAscending
    }
}
