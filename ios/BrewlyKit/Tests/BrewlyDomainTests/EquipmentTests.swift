import BrewlyDomain
import Foundation
import Testing

@Suite("Equipment")
struct EquipmentTests {
    private let c40 = Equipment(
        id: UUID(), kind: .grinder, grinderSlug: "comandante_c40_mk4", isDefault: true,
        grindSettings: ["v60": "24 clicks", "aeropress": "18 clicks"]
    )

    @Test("A new recipe gets the default grinder and its setting for the method")
    func prefillsUsualGrind() {
        var draft = RecipeDraft()
        draft.methodSlug = "v60"
        draft.applyUsualGrind(from: [c40])
        #expect(draft.grinderSlug == "comandante_c40_mk4")
        #expect(draft.grindSetting == "24 clicks")
    }

    @Test("Values already entered are kept")
    func keepsEnteredValues() {
        var otherGrinder = RecipeDraft()
        otherGrinder.methodSlug = "v60"
        otherGrinder.grinderSlug = "niche_zero"
        otherGrinder.applyUsualGrind(from: [c40])
        #expect(otherGrinder.grinderSlug == "niche_zero")
        #expect(otherGrinder.grindSetting.isEmpty)

        var typedSetting = RecipeDraft()
        typedSetting.methodSlug = "v60"
        typedSetting.grindSetting = "26 clicks"
        typedSetting.applyUsualGrind(from: [c40])
        #expect(typedSetting.grindSetting == "26 clicks")
    }

    @Test("Without a default grinder nothing changes")
    func noDefaultGrinder() {
        var draft = RecipeDraft()
        draft.methodSlug = "v60"
        var notDefault = c40
        notDefault.isDefault = false
        draft.applyUsualGrind(from: [notDefault])
        #expect(draft.grinderSlug == nil)
        #expect(draft.grindSetting.isEmpty)
    }

    @Test("Only grinders send their non-blank settings")
    func settingInputs() {
        var draft = EquipmentDraft(equipment: c40)
        draft.grindSettings["chemex"] = "  "
        #expect(draft.settingInputs.map(\.methodSlug) == ["aeropress", "v60"])
        draft.kind = .kettle
        #expect(draft.settingInputs.isEmpty)
    }

    @Test("The display name prefers the nickname, then the catalog grinder")
    func displayName() {
        let catalog = Catalog(
            grinders: [Grinder(slug: "comandante_c40_mk4", brand: "Comandante", model: "C40 MK4", kind: .manual)]
        )
        #expect(c40.displayName(in: catalog) == "Comandante C40 MK4")
        var named = c40
        named.nickname = "My C40"
        #expect(named.displayName(in: catalog) == "My C40")
        let kettle = Equipment(id: UUID(), kind: .kettle, brand: "Fellow", model: "Stagg EKG")
        #expect(kettle.displayName(in: catalog) == "Fellow Stagg EKG")
    }
}
