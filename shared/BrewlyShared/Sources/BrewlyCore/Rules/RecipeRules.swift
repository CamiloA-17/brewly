/// Recipe parameters checked by `RecipeRules`. Built from a request on the server
/// and from the form state in the app.
public struct RecipeParameters: Hashable, Sendable {
    public struct Step: Hashable, Sendable {
        public var startS: Int
        public var waterTargetG: Double?
        public var instruction: String?

        public init(startS: Int, waterTargetG: Double? = nil, instruction: String? = nil) {
            self.startS = startS
            self.waterTargetG = waterTargetG
            self.instruction = instruction
        }
    }

    public var title: String
    public var description: String?
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSetting: String?
    public var grindMicrons: Int?
    public var waterTempC: Double?
    public var bloomWaterG: Double?
    public var bloomTimeS: Int?
    public var totalTimeS: Int?
    public var pressureBar: Double?
    public var waterProfile: String?
    public var waterTdsPpm: Int?
    public var servings: Int?
    public var iceG: Double?
    public var milkG: Double?
    public var brewerDetail: String?
    public var notes: String?
    public var steps: [Step]

    public init(
        title: String,
        description: String? = nil,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        grindSetting: String? = nil,
        grindMicrons: Int? = nil,
        waterTempC: Double? = nil,
        bloomWaterG: Double? = nil,
        bloomTimeS: Int? = nil,
        totalTimeS: Int? = nil,
        pressureBar: Double? = nil,
        waterProfile: String? = nil,
        waterTdsPpm: Int? = nil,
        servings: Int? = nil,
        iceG: Double? = nil,
        milkG: Double? = nil,
        brewerDetail: String? = nil,
        notes: String? = nil,
        steps: [Step] = []
    ) {
        self.title = title
        self.description = description
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.grindSetting = grindSetting
        self.grindMicrons = grindMicrons
        self.waterTempC = waterTempC
        self.bloomWaterG = bloomWaterG
        self.bloomTimeS = bloomTimeS
        self.totalTimeS = totalTimeS
        self.pressureBar = pressureBar
        self.waterProfile = waterProfile
        self.waterTdsPpm = waterTdsPpm
        self.servings = servings
        self.iceG = iceG
        self.milkG = milkG
        self.brewerDetail = brewerDetail
        self.notes = notes
        self.steps = steps
    }
}

/// Validation rules for recipes. Limits mirror the CHECK constraints of the `recipes` table.
public enum RecipeRules {
    public static let titleMaxLength = 120
    public static let longTextMaxLength = 2_000
    public static let grindSettingMaxLength = 40
    public static let waterProfileMaxLength = 120
    public static let brewerDetailMaxLength = 80
    public static let stepInstructionMaxLength = 280
    public static let maxSteps = 50

    public static let doseRange: ClosedRange<Double> = 0.1...1_000
    public static let liquidRange: ClosedRange<Double> = 0.1...10_000
    public static let ratioRange: ClosedRange<Double> = 0.5...50
    public static let waterTempRange: ClosedRange<Double> = 0...100
    public static let bloomTimeRange: ClosedRange<Int> = 0...600
    public static let totalTimeRange: ClosedRange<Int> = 1...172_800
    public static let pressureRange: ClosedRange<Double> = 0.1...20
    public static let waterTdsRange: ClosedRange<Int> = 0...1_000
    public static let tdsRange: ClosedRange<Double> = 0.01...25
    public static let servingsRange: ClosedRange<Int> = 1...20
    public static let iceRange: ClosedRange<Double> = 0.1...5_000
    public static let milkRange: ClosedRange<Double> = 0.1...2_000
    public static let grindMicronsRange: ClosedRange<Int> = 50...2_000

    /// Returns every broken rule, or an empty array when the recipe is valid.
    ///
    /// - Parameter ratioBasis: the brew method's ratio basis. Filter methods (`.water`) require
    ///   brew water; espresso (`.beverage`) requires the beverage weight and rejects brew water.
    public static func validate(_ recipe: RecipeParameters, ratioBasis: RatioBasis) -> [RuleViolation] {
        var check = ViolationCollector()

        check.requireText(recipe.title, field: "title", maxLength: titleMaxLength)
        check.optionalText(recipe.description, field: "description", maxLength: longTextMaxLength)
        check.optionalText(recipe.notes, field: "notes", maxLength: longTextMaxLength)
        check.optionalText(recipe.grindSetting, field: "grindSetting", maxLength: grindSettingMaxLength)
        check.optionalText(recipe.waterProfile, field: "waterProfile", maxLength: waterProfileMaxLength)
        check.optionalText(recipe.brewerDetail, field: "brewerDetail", maxLength: brewerDetailMaxLength)

        check.range(recipe.doseG, field: "doseG", doseRange)
        check.range(recipe.waterG, field: "waterG", liquidRange)
        check.range(recipe.yieldG, field: "yieldG", liquidRange)

        switch ratioBasis {
        case .water:
            if recipe.waterG == nil { check.add("waterG", .required) }
        case .beverage:
            if recipe.yieldG == nil { check.add("yieldG", .required) }
            if recipe.waterG != nil { check.add("waterG", .notAllowed) }
        }

        if doseRange.contains(recipe.doseG),
           let ratio = BrewMath.ratio(doseG: recipe.doseG, waterG: recipe.waterG, yieldG: recipe.yieldG),
           !ratioRange.contains(ratio) {
            check.add("ratio", .outOfRange(min: ratioRange.lowerBound, max: ratioRange.upperBound))
        }

        check.range(recipe.grindMicrons, field: "grindMicrons", grindMicronsRange)
        check.range(recipe.waterTempC, field: "waterTempC", waterTempRange)
        check.range(recipe.bloomWaterG, field: "bloomWaterG", liquidRange)
        if let bloom = recipe.bloomWaterG, let water = recipe.waterG, bloom > water {
            check.add("bloomWaterG", .exceeds(field: "waterG"))
        }
        check.range(recipe.bloomTimeS, field: "bloomTimeS", bloomTimeRange)
        check.range(recipe.totalTimeS, field: "totalTimeS", totalTimeRange)
        check.range(recipe.pressureBar, field: "pressureBar", pressureRange)
        check.range(recipe.waterTdsPpm, field: "waterTdsPpm", waterTdsRange)
        check.range(recipe.servings, field: "servings", servingsRange)
        check.range(recipe.iceG, field: "iceG", iceRange)
        check.range(recipe.milkG, field: "milkG", milkRange)

        if recipe.steps.count > maxSteps {
            check.add("steps", .tooMany(max: maxSteps))
        }
        for (index, step) in recipe.steps.enumerated() {
            let prefix = "steps[\(index)]"
            if step.startS < 0 {
                check.add("\(prefix).startS", .outOfRange(min: 0, max: Double(totalTimeRange.upperBound)))
            }
            check.range(step.waterTargetG, field: "\(prefix).waterTargetG", liquidRange)
            check.optionalText(step.instruction, field: "\(prefix).instruction", maxLength: stepInstructionMaxLength)
        }

        return check.violations
    }
}
