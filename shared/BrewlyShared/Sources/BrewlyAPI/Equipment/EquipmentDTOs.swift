import Foundation

/// An item of a member's gear (`GET /me/equipment`, `GET /users/{id}/equipment`).
public struct EquipmentDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var kind: EquipmentKind
    /// Catalog grinder, when the item is one.
    public var grinderSlug: String?
    public var brand: String?
    public var model: String?
    public var nickname: String?
    public var notes: String?
    /// Used by default for its kind; at most one per kind.
    public var isDefault: Bool
    /// Usual setting per brew method (grinders only), sorted by method.
    public var grindSettings: [GrindSettingInput]
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
        grindSettings: [GrindSettingInput] = [],
        createdAt: Date
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
}

/// Body of `POST /me/equipment` and `PUT /me/equipment/{id}`.
public struct UpsertEquipmentRequest: Codable, Sendable, Equatable {
    public var kind: EquipmentKind
    public var grinderSlug: String?
    public var brand: String?
    public var model: String?
    public var nickname: String?
    public var notes: String?
    /// Making an item the default clears the previous default of its kind.
    public var isDefault: Bool
    /// Replaces every setting of the item. One per method.
    public var grindSettings: [GrindSettingInput]

    public init(
        kind: EquipmentKind,
        grinderSlug: String? = nil,
        brand: String? = nil,
        model: String? = nil,
        nickname: String? = nil,
        notes: String? = nil,
        isDefault: Bool = false,
        grindSettings: [GrindSettingInput] = []
    ) {
        self.kind = kind
        self.grinderSlug = grinderSlug
        self.brand = brand
        self.model = model
        self.nickname = nickname
        self.notes = notes
        self.isDefault = isDefault
        self.grindSettings = grindSettings
    }

    public var violations: [RuleViolation] {
        EquipmentRules.validate(
            kind: kind, grinderSlug: grinderSlug, brand: brand, model: model, nickname: nickname, notes: notes,
            grindSettings: grindSettings
        )
    }
}
