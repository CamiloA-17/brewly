/// Values measured or perceived during one preparation.
public struct BrewSessionParameters: Hashable, Sendable {
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSetting: String?
    public var waterTempC: Double?
    public var elapsedS: Int
    public var tdsPercent: Double?
    public var rating: Int?
    public var acidity: Int?
    public var bitterness: Int?
    public var body: Int?
    public var notes: String?

    public init(doseG: Double, waterG: Double?, yieldG: Double?, grindSetting: String?,
                waterTempC: Double?, elapsedS: Int, tdsPercent: Double?, rating: Int?,
                acidity: Int?, bitterness: Int?, body: Int?, notes: String?) {
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.grindSetting = grindSetting
        self.waterTempC = waterTempC
        self.elapsedS = elapsedS
        self.tdsPercent = tdsPercent
        self.rating = rating
        self.acidity = acidity
        self.bitterness = bitterness
        self.body = body
        self.notes = notes
    }
}

/// Limits mirror the `brew_sessions` checks; the same rules run in the app and API.
public enum BrewSessionRules {
    public static func validate(_ input: BrewSessionParameters) -> [RuleViolation] {
        var result = ViolationCollector()
        result.range(input.doseG, field: "doseG", 0.1...1000)
        result.range(input.waterG, field: "waterG", 0.1...10000)
        result.range(input.yieldG, field: "yieldG", 0.1...10000)
        if input.waterG == nil && input.yieldG == nil {
            result.add("waterG", .required)
        }
        result.optionalText(input.grindSetting, field: "grindSetting", maxLength: 40)
        result.range(input.waterTempC, field: "waterTempC", 0...100)
        result.range(input.elapsedS, field: "elapsedS", 0...172800)
        result.range(input.tdsPercent, field: "tdsPercent", 0.01...25)
        result.range(input.rating, field: "rating", 1...5)
        result.range(input.acidity, field: "acidity", 1...5)
        result.range(input.bitterness, field: "bitterness", 1...5)
        result.range(input.body, field: "body", 1...5)
        result.optionalText(input.notes, field: "notes", maxLength: 2000)
        return result.violations
    }
}
