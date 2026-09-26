import Foundation

/// An item of a member's gear.
public struct Equipment: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: EquipmentKind
    /// Catalog grinder, when the item is one.
    public var grinderSlug: String?
    public var brand: String?
    public var model: String?
    public var nickname: String?
    public var notes: String?
    /// Used by default for its kind.
    public var isDefault: Bool
    /// Usual grind setting by brew method slug (grinders only).
    public var grindSettings: [String: String]
    public var createdAt: Date

    public init(
        id: UUID,
        kind: EquipmentKind,
        grinderSlug: String? = nil,
        brand: String? = nil,
        model: String? = nil,
        nickname: String? = nil,
        notes: String? = nil,
        isDefault: Bool = false,
        grindSettings: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.grinderSlug = grinderSlug
        self.brand = brand
        self.model = model
        self.nickname = nickname
        self.notes = notes
        self.isDefault = isDefault
        self.grindSettings = grindSettings
        self.createdAt = createdAt
    }

    /// The nickname, else the catalog grinder, else brand and model.
    public func displayName(in catalog: Catalog) -> String {
        if let nickname { return nickname }
        if let grinder = catalog.grinders.first(where: { $0.slug == grinderSlug }) { return grinder.displayName }
        return [brand, model].compactMap { $0 }.joined(separator: " ")
    }
}

/// An item of gear being created or edited.
public struct EquipmentDraft: Hashable, Sendable {
    public var kind: EquipmentKind
    public var grinderSlug: String?
    public var brand = ""
    public var model = ""
    public var nickname = ""
    public var notes = ""
    public var isDefault = false
    /// Usual grind setting by brew method slug; blank values are dropped when saving.
    public var grindSettings: [String: String] = [:]

    public init(kind: EquipmentKind = .grinder) {
        self.kind = kind
    }

    public init(equipment: Equipment) {
        kind = equipment.kind
        grinderSlug = equipment.grinderSlug
        brand = equipment.brand ?? ""
        model = equipment.model ?? ""
        nickname = equipment.nickname ?? ""
        notes = equipment.notes ?? ""
        isDefault = equipment.isDefault
        grindSettings = equipment.grindSettings
    }

    /// Settings sent to the API: grinders only, without blank values, sorted by method.
    public var settingInputs: [GrindSettingInput] {
        guard kind == .grinder else { return [] }
        return grindSettings
            .filter { !$0.value.trimmingWhitespace.isEmpty }
            .map { GrindSettingInput(methodSlug: $0.key, grindSetting: $0.value.trimmingWhitespace) }
            .sorted { $0.methodSlug < $1.methodSlug }
    }

    public var violations: [RuleViolation] {
        EquipmentRules.validate(
            kind: kind, grinderSlug: kind == .grinder ? grinderSlug : nil, brand: brand, model: model,
            nickname: nickname, notes: notes, grindSettings: settingInputs
        )
    }
}
