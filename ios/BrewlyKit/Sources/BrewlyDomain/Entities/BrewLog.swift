import Foundation

/// A cup in the brew journal: the parameters actually used and how it tasted.
public struct BrewLog: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var user: UserSummary
    /// The recipe followed, when it still exists and is visible.
    public var recipe: RecipeReference?
    public var bean: BeanSummary
    public var methodSlug: String
    public var equipmentID: UUID?
    public var brewedAt: Date
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var ratio: Double?
    public var grindSize: GrindSize?
    public var grindSetting: String?
    public var waterTempC: Double?
    public var totalTimeS: Int?
    public var tasting: Tasting
    public var tdsPercent: Double?
    public var extractionYieldPercent: Double?
    public var flavorNoteSlugs: [String]
    public var notes: String?
    public var photoURL: URL?
    public var visibility: Visibility
    public var createdAt: Date

    public init(
        id: UUID,
        user: UserSummary,
        recipe: RecipeReference? = nil,
        bean: BeanSummary,
        methodSlug: String,
        equipmentID: UUID? = nil,
        brewedAt: Date,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        ratio: Double? = nil,
        grindSize: GrindSize? = nil,
        grindSetting: String? = nil,
        waterTempC: Double? = nil,
        totalTimeS: Int? = nil,
        tasting: Tasting = Tasting(),
        tdsPercent: Double? = nil,
        extractionYieldPercent: Double? = nil,
        flavorNoteSlugs: [String] = [],
        notes: String? = nil,
        photoURL: URL? = nil,
        visibility: Visibility = .private,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.user = user
        self.recipe = recipe
        self.bean = bean
        self.methodSlug = methodSlug
        self.equipmentID = equipmentID
        self.brewedAt = brewedAt
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.ratio = ratio
        self.grindSize = grindSize
        self.grindSetting = grindSetting
        self.waterTempC = waterTempC
        self.totalTimeS = totalTimeS
        self.tasting = tasting
        self.tdsPercent = tdsPercent
        self.extractionYieldPercent = extractionYieldPercent
        self.flavorNoteSlugs = flavorNoteSlugs
        self.notes = notes
        self.photoURL = photoURL
        self.visibility = visibility
        self.createdAt = createdAt
    }
}

/// How a cup tasted. Every score goes from 1 to 5.
public struct Tasting: Hashable, Sendable {
    public var rating: Int?
    public var acidity: Int?
    public var sweetness: Int?
    public var body: Int?
    public var bitterness: Int?
    public var aftertaste: Int?

    public init(
        rating: Int? = nil,
        acidity: Int? = nil,
        sweetness: Int? = nil,
        body: Int? = nil,
        bitterness: Int? = nil,
        aftertaste: Int? = nil
    ) {
        self.rating = rating
        self.acidity = acidity
        self.sweetness = sweetness
        self.body = body
        self.bitterness = bitterness
        self.aftertaste = aftertaste
    }

    /// The attributes of the cup, in display order.
    public enum Attribute: CaseIterable, Hashable, Sendable {
        case acidity, sweetness, body, bitterness, aftertaste
    }

    public subscript(attribute: Attribute) -> Int? {
        get {
            switch attribute {
            case .acidity: acidity
            case .sweetness: sweetness
            case .body: body
            case .bitterness: bitterness
            case .aftertaste: aftertaste
            }
        }
        set {
            switch attribute {
            case .acidity: acidity = newValue
            case .sweetness: sweetness = newValue
            case .body: body = newValue
            case .bitterness: bitterness = newValue
            case .aftertaste: aftertaste = newValue
            }
        }
    }
}

/// Filters of the journal.
public struct BrewLogFilter: Hashable, Sendable {
    public var beanID: UUID?
    public var methodSlug: String?

    public init(beanID: UUID? = nil, methodSlug: String? = nil) {
        self.beanID = beanID
        self.methodSlug = methodSlug
    }
}

/// Editable state of a brew journal entry.
public struct BrewLogDraft: Hashable, Sendable {
    public var recipeID: UUID?
    /// Title of the followed recipe, to show it in the form.
    public var recipeTitle: String?
    public var beanID: UUID?
    public var methodSlug: String?
    public var equipmentID: UUID?
    public var brewedAt = Date()
    public var doseG: Double?
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSize: GrindSize?
    public var grindSetting = ""
    public var waterTempC: Double?
    public var totalTimeS: Int?
    public var tasting = Tasting()
    public var tdsPercent: Double?
    public var flavorNoteSlugs: Set<String> = []
    public var notes = ""
    /// The current photo; `nil` removes it when saving.
    public var photoURL: URL?
    /// A newly picked photo, uploaded when saving.
    public var newPhotoData: Data?
    public var visibility: Visibility = .private

    public init() {}

    /// A new brew that follows a recipe: its parameters, without the author's bean (the member
    /// brews one of their own) and with an empty tasting.
    public init(recipe: Recipe) {
        recipeID = recipe.id
        recipeTitle = recipe.title
        methodSlug = recipe.methodSlug
        doseG = recipe.doseG
        waterG = recipe.waterG
        yieldG = recipe.yieldG
        grindSize = recipe.grindSize
        grindSetting = recipe.grindSetting ?? ""
        waterTempC = recipe.waterTempC
        totalTimeS = recipe.totalTimeS
    }

    public init(brewLog: BrewLog) {
        recipeID = brewLog.recipe?.id
        recipeTitle = brewLog.recipe?.title
        beanID = brewLog.bean.id
        methodSlug = brewLog.methodSlug
        equipmentID = brewLog.equipmentID
        brewedAt = brewLog.brewedAt
        doseG = brewLog.doseG
        waterG = brewLog.waterG
        yieldG = brewLog.yieldG
        grindSize = brewLog.grindSize
        grindSetting = brewLog.grindSetting ?? ""
        waterTempC = brewLog.waterTempC
        totalTimeS = brewLog.totalTimeS
        tasting = brewLog.tasting
        tdsPercent = brewLog.tdsPercent
        flavorNoteSlugs = Set(brewLog.flavorNoteSlugs)
        notes = brewLog.notes ?? ""
        photoURL = brewLog.photoURL
        visibility = brewLog.visibility
    }

    /// Live brew ratio, computed like the database does.
    public var ratio: Double? {
        doseG.flatMap { BrewMath.ratio(doseG: $0, waterG: waterG, yieldG: yieldG) }
    }

    /// Live extraction yield percentage.
    public var extractionYield: Double? {
        doseG.flatMap { BrewMath.extractionYield(doseG: $0, beverageG: yieldG, tdsPercent: tdsPercent) }
    }

    /// Fills the grinder setting from the member's gear: the chosen grinder, else the default one.
    public mutating func applyUsualGrind(from equipment: [Equipment]) {
        let grinders = equipment.filter { $0.kind == .grinder }
        guard let grinder = grinders.first(where: { $0.id == equipmentID }) ?? grinders.first(where: \.isDefault)
        else { return }
        if equipmentID == nil { equipmentID = grinder.id }
        guard grindSetting.trimmingWhitespace.isEmpty, let methodSlug,
              let setting = grinder.grindSettings[methodSlug]
        else { return }
        grindSetting = setting
    }
}
