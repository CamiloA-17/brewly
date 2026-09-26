import Foundation

/// Brew journal fields checked by `BrewRules`.
public struct BrewParameters: Hashable, Sendable {
    public var brewedAt: Date
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSetting: String?
    public var waterTempC: Double?
    public var totalTimeS: Int?
    public var rating: Int?
    public var acidity: Int?
    public var sweetness: Int?
    public var body: Int?
    public var bitterness: Int?
    public var aftertaste: Int?
    public var tdsPercent: Double?
    public var notes: String?

    public init(
        brewedAt: Date,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        grindSetting: String? = nil,
        waterTempC: Double? = nil,
        totalTimeS: Int? = nil,
        rating: Int? = nil,
        acidity: Int? = nil,
        sweetness: Int? = nil,
        body: Int? = nil,
        bitterness: Int? = nil,
        aftertaste: Int? = nil,
        tdsPercent: Double? = nil,
        notes: String? = nil
    ) {
        self.brewedAt = brewedAt
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.grindSetting = grindSetting
        self.waterTempC = waterTempC
        self.totalTimeS = totalTimeS
        self.rating = rating
        self.acidity = acidity
        self.sweetness = sweetness
        self.body = body
        self.bitterness = bitterness
        self.aftertaste = aftertaste
        self.tdsPercent = tdsPercent
        self.notes = notes
    }
}

/// Validation rules for the brew journal. Limits mirror the CHECK constraints of `brew_logs`,
/// which reuse the recipe limits.
public enum BrewRules {
    public static let tastingRange: ClosedRange<Int> = 1...5
    /// Clock skew allowed for `brewedAt` before it counts as in the future.
    public static let futureTolerance: TimeInterval = 5 * 60

    /// - Parameter ratioBasis: the brew method's ratio basis (see `RecipeRules.validate`).
    public static func validate(_ brew: BrewParameters, ratioBasis: RatioBasis, now: Date = Date()) -> [RuleViolation] {
        var check = ViolationCollector()

        if brew.brewedAt > now.addingTimeInterval(futureTolerance) {
            check.add("brewedAt", .inFuture)
        }
        check.range(brew.doseG, field: "doseG", RecipeRules.doseRange)
        check.range(brew.waterG, field: "waterG", RecipeRules.liquidRange)
        check.range(brew.yieldG, field: "yieldG", RecipeRules.liquidRange)
        switch ratioBasis {
        case .water:
            if brew.waterG == nil { check.add("waterG", .required) }
        case .beverage:
            if brew.yieldG == nil { check.add("yieldG", .required) }
            if brew.waterG != nil { check.add("waterG", .notAllowed) }
        }
        if RecipeRules.doseRange.contains(brew.doseG),
           let ratio = BrewMath.ratio(doseG: brew.doseG, waterG: brew.waterG, yieldG: brew.yieldG),
           !RecipeRules.ratioRange.contains(ratio) {
            check.add("ratio", .outOfRange(min: RecipeRules.ratioRange.lowerBound, max: RecipeRules.ratioRange.upperBound))
        }
        check.optionalText(brew.grindSetting, field: "grindSetting", maxLength: RecipeRules.grindSettingMaxLength)
        check.range(brew.waterTempC, field: "waterTempC", RecipeRules.waterTempRange)
        check.range(brew.totalTimeS, field: "totalTimeS", RecipeRules.totalTimeRange)
        check.range(brew.tdsPercent, field: "tdsPercent", RecipeRules.tdsRange)
        check.range(brew.rating, field: "rating", tastingRange)
        check.range(brew.acidity, field: "acidity", tastingRange)
        check.range(brew.sweetness, field: "sweetness", tastingRange)
        check.range(brew.body, field: "body", tastingRange)
        check.range(brew.bitterness, field: "bitterness", tastingRange)
        check.range(brew.aftertaste, field: "aftertaste", tastingRange)
        check.optionalText(brew.notes, field: "notes", maxLength: RecipeRules.longTextMaxLength)
        return check.violations
    }
}
