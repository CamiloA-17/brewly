import BrewlyCore
import Testing

@Suite("BrewSessionRules")
struct BrewSessionRulesTests {
    @Test func acceptsMeasuredCup() {
        #expect(BrewSessionRules.validate(sample()).isEmpty)
    }

    @Test func requiresLiquidAndBoundsTasteScores() {
        var cup = sample()
        cup.waterG = nil
        cup.yieldG = nil
        cup.acidity = 6
        let violations = BrewSessionRules.validate(cup)
        #expect(Set(violations.map(\.field)) == ["waterG", "acidity"])
    }

    private func sample() -> BrewSessionParameters {
        BrewSessionParameters(doseG: 15, waterG: 250, yieldG: 215,
                              grindSetting: "24 clicks", waterTempC: 93,
                              elapsedS: 180, tdsPercent: 1.38, rating: 4,
                              acidity: 3, bitterness: 2, body: 4, notes: "Floral")
    }
}
