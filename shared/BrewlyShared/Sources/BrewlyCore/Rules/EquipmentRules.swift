/// A member's grinder setting for one brew method.
public struct GrindSettingInput: Codable, Hashable, Sendable {
    public var methodSlug: String
    public var grindSetting: String

    public init(methodSlug: String, grindSetting: String) {
        self.methodSlug = methodSlug
        self.grindSetting = grindSetting
    }
}

/// Validation rules for equipment. Limits mirror the `user_equipment` and `equipment_grind_settings` tables.
public enum EquipmentRules {
    public static let nameMaxLength = 60
    public static let notesMaxLength = 500
    /// Same limit as recipes, since it pre-fills them.
    public static let grindSettingMaxLength = RecipeRules.grindSettingMaxLength

    public static func validate(
        kind: EquipmentKind,
        grinderSlug: String?,
        brand: String?,
        model: String?,
        nickname: String?,
        notes: String?,
        grindSettings: [GrindSettingInput]
    ) -> [RuleViolation] {
        var check = ViolationCollector()
        let grinderSlug = grinderSlug?.trimmingWhitespace ?? ""
        if !grinderSlug.isEmpty && kind != .grinder {
            check.add("grinderSlug", .notAllowed)
        }
        let names = [brand, model, nickname].map { $0?.trimmingWhitespace ?? "" }
        if grinderSlug.isEmpty && names.allSatisfy(\.isEmpty) {
            check.add("model", .required)
        }
        check.optionalText(brand, field: "brand", maxLength: nameMaxLength)
        check.optionalText(model, field: "model", maxLength: nameMaxLength)
        check.optionalText(nickname, field: "nickname", maxLength: nameMaxLength)
        check.optionalText(notes, field: "notes", maxLength: notesMaxLength)

        if !grindSettings.isEmpty && kind != .grinder {
            check.add("grindSettings", .notAllowed)
        }
        for (index, setting) in grindSettings.enumerated() {
            check.requireText(setting.grindSetting, field: "grindSettings[\(index)].grindSetting", maxLength: grindSettingMaxLength)
        }
        return check.violations
    }
}
