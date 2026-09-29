import Foundation

/// Editable state of a recipe form.
public struct RecipeDraft: Hashable, Sendable {
    public struct Step: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var kind: BrewStepKind
        public var startS: Int
        public var waterTargetG: Double?
        public var instruction: String

        public init(id: UUID = UUID(), kind: BrewStepKind = .pour, startS: Int = 0, waterTargetG: Double? = nil, instruction: String = "") {
            self.id = id
            self.kind = kind
            self.startS = startS
            self.waterTargetG = waterTargetG
            self.instruction = instruction
        }
    }

    public var beanID: UUID?
    /// The recipe this draft remixes. Only sent when creating a recipe.
    public var forkedFromID: UUID?
    public var methodSlug: String?
    public var title = ""
    public var description = ""
    public var doseG: Double?
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSize: GrindSize = .medium
    public var grinderSlug: String?
    public var grindSetting = ""
    public var grindMicrons: Int?
    public var waterTempC: Double?
    public var bloomWaterG: Double?
    public var bloomTimeS: Int?
    public var totalTimeS: Int?
    public var pressureBar: Double?
    public var filterType: FilterType?
    public var waterProfile = ""
    public var waterTdsPpm: Int?
    public var tdsPercent: Double?
    public var rating: Int?
    public var notes = ""
    public var flavorNoteSlugs: Set<String> = []
    public var steps: [Step] = []
    public var visibility: Visibility = .public

    public init() {}

    public init(recipe: Recipe) {
        beanID = recipe.bean.id
        methodSlug = recipe.methodSlug
        title = recipe.title
        description = recipe.description ?? ""
        doseG = recipe.doseG
        waterG = recipe.waterG
        yieldG = recipe.yieldG
        grindSize = recipe.grindSize
        grinderSlug = recipe.grinderSlug
        grindSetting = recipe.grindSetting ?? ""
        grindMicrons = recipe.grindMicrons
        waterTempC = recipe.waterTempC
        bloomWaterG = recipe.bloomWaterG
        bloomTimeS = recipe.bloomTimeS
        totalTimeS = recipe.totalTimeS
        pressureBar = recipe.pressureBar
        filterType = recipe.filterType
        waterProfile = recipe.waterProfile ?? ""
        waterTdsPpm = recipe.waterTdsPpm
        tdsPercent = recipe.tdsPercent
        rating = recipe.rating
        notes = recipe.notes ?? ""
        flavorNoteSlugs = Set(recipe.flavorNoteSlugs)
        steps = recipe.steps.map {
            Step(kind: $0.kind, startS: $0.startS, waterTargetG: $0.waterTargetG, instruction: $0.instruction ?? "")
        }
        visibility = recipe.visibility
    }

    /// A new recipe that starts from someone else's parameters.
    ///
    /// The brewer picks one of their own beans, and results (TDS, rating, tasting notes) start
    /// empty because they belong to each cup.
    public init(remixOf recipe: Recipe) {
        self.init(recipe: recipe)
        beanID = nil
        forkedFromID = recipe.id
        tdsPercent = nil
        rating = nil
        notes = ""
        flavorNoteSlugs = []
        visibility = .public
    }

    /// Live brew ratio, computed like the database does.
    public var ratio: Double? {
        doseG.flatMap { BrewMath.ratio(doseG: $0, waterG: waterG, yieldG: yieldG) }
    }

    /// Live extraction yield percentage.
    public var extractionYield: Double? {
        doseG.flatMap { BrewMath.extractionYield(doseG: $0, beverageG: yieldG, tdsPercent: tdsPercent) }
    }

    /// Pre-fills the grinder and its usual setting for the selected method from the member's default
    /// grinder. Values the member already entered are kept.
    public mutating func applyUsualGrind(from equipment: [Equipment]) {
        guard let grinder = equipment.first(where: { $0.kind == .grinder && $0.isDefault }) else { return }
        if grinderSlug == nil, let slug = grinder.grinderSlug {
            grinderSlug = slug
        }
        guard grinderSlug == grinder.grinderSlug, grindSetting.trimmingWhitespace.isEmpty,
              let methodSlug, let setting = grinder.grindSettings[methodSlug]
        else { return }
        grindSetting = setting
    }

    /// Fills empty parameters with the brew method's suggestions.
    public mutating func applyDefaults(of method: BrewMethod) {
        methodSlug = method.slug
        if let grind = method.defaultGrindSize { grindSize = grind }
        if waterTempC == nil { waterTempC = method.defaultWaterTempC }
        if method.ratioBasis == .beverage {
            // Espresso ratios are expressed by beverage weight; brew water does not apply.
            waterG = nil
            bloomWaterG = nil
        }
        guard let dose = doseG, let ratio = method.defaultRatio else { return }
        switch method.ratioBasis {
        case .water where waterG == nil:
            waterG = BrewMath.liquid(forDoseG: dose, ratio: ratio)
        case .beverage where yieldG == nil:
            yieldG = BrewMath.liquid(forDoseG: dose, ratio: ratio)
        default:
            break
        }
    }
}

/// A validated recipe ready to be saved.
public struct RecipeInput: Hashable, Sendable {
    public var beanID: UUID
    public var methodSlug: String
    public var draft: RecipeDraft

    public init(beanID: UUID, methodSlug: String, draft: RecipeDraft) {
        self.beanID = beanID
        self.methodSlug = methodSlug
        self.draft = draft
    }
}
