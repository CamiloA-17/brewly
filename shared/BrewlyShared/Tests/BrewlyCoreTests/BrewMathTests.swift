import BrewlyCore
import Testing

@Suite("BrewMath")
struct BrewMathTests {
    @Test("Filter ratio uses brew water")
    func filterRatio() {
        #expect(BrewMath.ratio(doseG: 15, waterG: 250, yieldG: 215) == 16.67)
    }

    @Test("Espresso ratio uses beverage weight")
    func espressoRatio() {
        #expect(BrewMath.ratio(doseG: 18, waterG: nil, yieldG: 36) == 2)
    }

    @Test("Ratio needs a dose and a liquid")
    func ratioNeedsInputs() {
        #expect(BrewMath.ratio(doseG: 0, waterG: 250, yieldG: nil) == nil)
        #expect(BrewMath.ratio(doseG: 15, waterG: nil, yieldG: nil) == nil)
    }

    @Test("Extraction yield matches the database formula")
    func extractionYield() {
        #expect(BrewMath.extractionYield(doseG: 15, beverageG: 215, tdsPercent: 1.38) == 19.78)
        #expect(BrewMath.extractionYield(doseG: 18, beverageG: 40, tdsPercent: 9.5) == 21.11)
        #expect(BrewMath.extractionYield(doseG: 18, beverageG: 40, tdsPercent: nil) == nil)
    }

    @Test("Liquid for a target ratio")
    func liquidForRatio() {
        #expect(BrewMath.liquid(forDoseG: 15, ratio: 16) == 240)
    }
}
