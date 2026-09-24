@testable import BrewlyDomain
import XCTest

final class BrewMathTests: XCTestCase {
    func testRatio() {
        XCTAssertEqual(BrewMath.ratio(dose: 15, water: 250), Decimal(string: "16.67"))
        XCTAssertNil(BrewMath.ratio(dose: 15, water: nil))
        XCTAssertNil(BrewMath.ratio(dose: 0, water: 250))
    }

    func testWaterAndDoseForRatio() {
        XCTAssertEqual(BrewMath.water(forDose: 20, ratio: 16), 320)
        XCTAssertEqual(BrewMath.dose(forWater: 500, ratio: 16), Decimal(string: "31.3"))
    }

    func testExtractionYield() {
        // 36 g de espresso con 9.5 % TDS y 18 g de dosis → 19 %
        XCTAssertEqual(BrewMath.extractionYield(beverageG: 36, tds: Decimal(string: "9.5")!, dose: 18), 19)
    }

    func testScaleRecipeKeepsProportions() {
        let recipe = Recipe(
            ownerID: UUID(), title: "V60", brewMethodID: UUID(), doseG: 15, waterG: 250,
            steps: [
                RecipeStep(position: 0, kind: .bloom, instruction: "Bloom", waterG: 45),
                RecipeStep(position: 1, kind: .pour, instruction: "Vertido", waterG: 205),
            ]
        )
        let scaled = BrewMath.scale(recipe, toDose: 30)
        XCTAssertEqual(scaled.waterG, 500)
        XCTAssertEqual(scaled.steps.map(\.waterG), [90, 410])
        XCTAssertEqual(scaled.ratio, recipe.computedRatio)
    }
}
