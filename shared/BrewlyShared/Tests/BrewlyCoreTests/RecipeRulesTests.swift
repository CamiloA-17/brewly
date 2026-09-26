import BrewlyCore
import Testing

@Suite("RecipeRules")
struct RecipeRulesTests {
    private func fields(_ violations: [RuleViolation]) -> Set<String> {
        Set(violations.map(\.field))
    }

    @Test("A complete V60 recipe is valid")
    func validFilterRecipe() {
        let recipe = RecipeParameters(
            title: "Morning V60", doseG: 15, waterG: 250, yieldG: 215,
            waterTempC: 93, bloomWaterG: 45, bloomTimeS: 45, totalTimeS: 180, servings: 1, iceG: 80,
            steps: [.init(startS: 0, waterTargetG: 45), .init(startS: 45, waterTargetG: 250)]
        )
        #expect(RecipeRules.validate(recipe, ratioBasis: .water).isEmpty)
    }

    @Test("Filter methods require brew water")
    func filterRequiresWater() {
        let recipe = RecipeParameters(title: "No water", doseG: 15)
        let violations = RecipeRules.validate(recipe, ratioBasis: .water)
        #expect(violations == [RuleViolation(field: "waterG", kind: .required)])
    }

    @Test("Espresso requires the beverage weight and rejects brew water")
    func espressoRules() {
        let recipe = RecipeParameters(title: "Shot", doseG: 18, waterG: 60)
        #expect(fields(RecipeRules.validate(recipe, ratioBasis: .beverage)) == ["yieldG", "waterG"])
        let valid = RecipeParameters(title: "Shot", doseG: 18, yieldG: 36, pressureBar: 9)
        #expect(RecipeRules.validate(valid, ratioBasis: .beverage).isEmpty)
    }

    @Test("Out-of-range values are reported")
    func ranges() {
        let recipe = RecipeParameters(
            title: "  ", doseG: 1, waterG: 900, waterTempC: 120, bloomWaterG: 950, servings: 0
        )
        let violations = RecipeRules.validate(recipe, ratioBasis: .water)
        #expect(fields(violations) == ["title", "ratio", "waterTempC", "bloomWaterG", "servings"])
        #expect(violations.contains(RuleViolation(field: "bloomWaterG", kind: .exceeds(field: "waterG"))))
    }

    @Test("Step fields are reported with their index")
    func steps() {
        let recipe = RecipeParameters(
            title: "Steps", doseG: 15, waterG: 250,
            steps: [.init(startS: 0), .init(startS: -5, waterTargetG: 0)]
        )
        #expect(fields(RecipeRules.validate(recipe, ratioBasis: .water)) == ["steps[1].startS", "steps[1].waterTargetG"])
    }
}
