import Foundation

struct ProfileInsights: Equatable, Sendable {
    let totalCatches: Int
    let personalBest: CatchItem?
    let speciesCount: Int
    let speciesBreakdown: [DashboardLabelStat]

    var signatureSpecies: DashboardLabelStat? {
        speciesBreakdown.first
    }
}

enum ProfileDerivation {
    static func insights(from catches: [CatchItem]) -> ProfileInsights {
        let summary = DashboardDerivation.recordSummary(from: catches)
        return ProfileInsights(
            totalCatches: summary.totalCatches,
            personalBest: summary.biggestCatch,
            speciesCount: summary.speciesBreakdown.count,
            speciesBreakdown: summary.speciesBreakdown
        )
    }
}
