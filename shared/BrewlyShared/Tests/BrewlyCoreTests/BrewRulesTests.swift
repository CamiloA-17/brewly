import BrewlyCore
import Foundation
import Testing

@Suite("BrewRules")
struct BrewRulesTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("A complete V60 brew is valid")
    func validBrew() {
        let brew = BrewParameters(
            brewedAt: now, doseG: 15, waterG: 250, yieldG: 215, grindSetting: "24 clicks", waterTempC: 93,
            totalTimeS: 180, rating: 4, acidity: 4, sweetness: 5, body: 3, bitterness: 1, aftertaste: 4, tdsPercent: 1.38
        )
        #expect(BrewRules.validate(brew, ratioBasis: .water, now: now).isEmpty)
    }

    @Test("Tasting scores, water and dates are checked")
    func invalidBrew() {
        let brew = BrewParameters(
            brewedAt: now.addingTimeInterval(3_600), doseG: 18, waterG: 40, rating: 0, bitterness: 6
        )
        let fields = Set(BrewRules.validate(brew, ratioBasis: .beverage, now: now).map(\.field))
        #expect(fields == ["brewedAt", "yieldG", "waterG", "rating", "bitterness"])
    }

    @Test("A few minutes of clock skew are allowed")
    func clockSkew() {
        let brew = BrewParameters(brewedAt: now.addingTimeInterval(60), doseG: 15, waterG: 250)
        #expect(BrewRules.validate(brew, ratioBasis: .water, now: now).isEmpty)
    }
}
