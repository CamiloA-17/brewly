import BrewlyDomain
import Foundation
import Testing

@Suite("Brew journal")
struct BrewLogTests {
    private let v60 = BrewMethod(slug: "v60", name: "V60", category: .pourOver, ratioBasis: .water)

    @Test("A draft computes the ratio and extraction yield like the database")
    func liveValues() {
        var draft = BrewLogDraft()
        draft.doseG = 15
        draft.waterG = 250
        draft.yieldG = 215
        draft.tdsPercent = 1.38
        #expect(draft.ratio == 16.67)
        #expect(draft.extractionYield == 19.78)
    }

    @Test("A brew needs a bean, a method and a dose")
    func requiredFields() {
        let fields = Set(SaveBrewLogUseCase.violations(for: BrewLogDraft(), method: nil).map(\.field))
        #expect(fields == ["beanId", "methodSlug", "doseG"])
    }

    @Test("Tasting scores go from 1 to 5")
    func tastingRange() {
        var draft = BrewLogDraft()
        draft.beanID = UUID()
        draft.doseG = 15
        draft.waterG = 250
        draft.tasting[.bitterness] = 6
        let violations = SaveBrewLogUseCase.violations(for: draft, method: v60)
        #expect(violations.map(\.field) == ["bitterness"])
    }

    @Test("A chosen grinder wins over the default one")
    func chosenGrinder() {
        let usual = Equipment(id: UUID(), kind: .grinder, brand: "Kingrinder", model: "K6", isDefault: true,
                              grindSettings: ["v60": "90"])
        let travel = Equipment(id: UUID(), kind: .grinder, brand: "Timemore", model: "C3",
                               grindSettings: ["v60": "18 clicks"])
        var draft = BrewLogDraft()
        draft.methodSlug = "v60"
        draft.equipmentID = travel.id
        draft.applyUsualGrind(from: [usual, travel])
        #expect(draft.grindSetting == "18 clicks")
    }
}
