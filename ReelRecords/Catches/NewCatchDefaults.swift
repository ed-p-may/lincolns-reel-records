import Foundation

struct NewCatchDefaults: Equatable, Sendable {
    let location: String?
    let tackleItemID: UUID?
    let lureText: String?
    let skyCondition: SkyCondition?
    let waterClarity: WaterClarity?

    init(catchItem: CatchItem) {
        location = catchItem.location
        tackleItemID = catchItem.tackleItemID
        lureText = catchItem.lureText
        skyCondition = catchItem.conditions.skyCondition
        waterClarity = catchItem.conditions.waterClarity
    }
}
