import BrewlyDomain
import Foundation
import Testing

@Suite("RecipeDraft")
struct RecipeDraftTests {
    private let v60 = BrewMethod(
        slug: "v60", name: "V60", category: .pourOver, ratioBasis: .water,
        defaultRatio: 16, defaultGrindSize: .mediumFine, defaultWaterTempC: 93
    )
    private let espresso = BrewMethod(
        slug: "espresso", name: "Espresso", category: .espresso, ratioBasis: .beverage,
        defaultRatio: 2, defaultGrindSize: .fine, defaultWaterTempC: 93
    )

    @Test("Method defaults fill empty parameters")
    func appliesDefaults() {
        var draft = RecipeDraft()
        draft.doseG = 15
        draft.applyDefaults(of: v60)
        #expect(draft.methodSlug == "v60")
        #expect(draft.waterG == 240)
        #expect(draft.grindSize == .mediumFine)
        #expect(draft.waterTempC == 93)
        #expect(draft.ratio == 16)
    }

    @Test("Switching to espresso drops brew water and uses the beverage weight")
    func switchesToEspresso() {
        var draft = RecipeDraft()
        draft.doseG = 18
        draft.applyDefaults(of: v60)
        draft.applyDefaults(of: espresso)
        #expect(draft.waterG == nil)
        #expect(draft.yieldG == 36)
        #expect(draft.ratio == 2)
    }

    @Test("Live extraction yield")
    func extractionYield() {
        var draft = RecipeDraft()
        draft.doseG = 15
        draft.yieldG = 215
        draft.tdsPercent = 1.38
        #expect(draft.extractionYield == 19.78)
    }
}

@Suite("SaveRecipeUseCase")
struct SaveRecipeUseCaseTests {
    @Test("Reports missing bean, method and dose")
    func missingRequiredFields() {
        let fields = SaveRecipeUseCase.violations(for: RecipeDraft(), method: nil).map(\.field)
        #expect(fields == ["beanId", "methodSlug", "doseG"])
    }

    @Test("Uses the method's ratio basis")
    func ratioBasis() {
        var draft = RecipeDraft()
        draft.beanID = UUID()
        draft.title = "Shot"
        draft.doseG = 18
        let espresso = BrewMethod(slug: "espresso", name: "Espresso", category: .espresso, ratioBasis: .beverage)
        #expect(SaveRecipeUseCase.violations(for: draft, method: espresso).map(\.field) == ["yieldG"])
        draft.yieldG = 36
        #expect(SaveRecipeUseCase.violations(for: draft, method: espresso).isEmpty)
    }
}

@Suite("Bean")
struct BeanTests {
    @Test("Days since roast")
    func daysSinceRoast() {
        let bean = Bean(id: UUID(), ownerID: UUID(), name: "Test", roastDate: CalendarDate(year: 2026, month: 9, day: 10))
        #expect(bean.daysSinceRoast(today: CalendarDate(year: 2026, month: 9, day: 25)!) == 15)
    }

    @Test("A draft round-trips the bean's editable fields")
    func draftFromBean() {
        let bean = Bean(
            id: UUID(), ownerID: UUID(), name: "Geisha", farm: "Finca Las Nubes",
            varietalSlugs: ["geisha"], roastLevel: .light, isArchived: true
        )
        let draft = BeanDraft(bean: bean)
        #expect(draft.name == "Geisha")
        #expect(draft.farm == "Finca Las Nubes")
        #expect(draft.varietalSlugs == ["geisha"])
        #expect(draft.roastLevel == .light)
        #expect(draft.isArchived)
    }
}
