import BrewlyCore
import Testing

@Suite("EquipmentRules")
struct EquipmentRulesTests {
    @Test("A catalog grinder with settings is valid")
    func grinder() {
        #expect(EquipmentRules.validate(
            kind: .grinder, grinderSlug: "comandante_c40_mk4", brand: nil, model: nil, nickname: nil, notes: nil,
            grindSettings: [GrindSettingInput(methodSlug: "v60", grindSetting: "24 clicks")]
        ).isEmpty)
    }

    @Test("Other gear needs a name and takes no catalog grinder or settings")
    func otherGear() {
        let fields = Set(EquipmentRules.validate(
            kind: .kettle, grinderSlug: "comandante_c40_mk4", brand: nil, model: nil, nickname: nil, notes: nil,
            grindSettings: [GrindSettingInput(methodSlug: "v60", grindSetting: " ")]
        ).map(\.field))
        #expect(fields == ["grinderSlug", "grindSettings", "grindSettings[0].grindSetting"])

        let unnamed = EquipmentRules.validate(
            kind: .scale, grinderSlug: nil, brand: " ", model: nil, nickname: nil, notes: nil, grindSettings: []
        )
        #expect(unnamed == [RuleViolation(field: "model", kind: .required)])
    }
}
