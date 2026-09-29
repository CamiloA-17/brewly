import Foundation

/// A cup in the brew journal (`GET /me/brews`, `GET /brews/{id}`).
public struct BrewLogDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var user: UserSummaryDTO
    /// The recipe followed, when it still exists and the viewer can see it.
    public var recipe: RecipeReferenceDTO?
    public var bean: BeanSummaryDTO
    public var methodSlug: String
    /// The member's equipment used, if still owned.
    public var equipmentId: UUID?
    public var brewedAt: Date
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var ratio: Double?
    public var grindSize: GrindSize?
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
    public var extractionYieldPercent: Double?
    public var flavorNoteSlugs: [String]
    public var notes: String?
    public var photoURL: String?
    public var visibility: Visibility
    public var createdAt: Date

    public init(
        id: UUID,
        user: UserSummaryDTO,
        recipe: RecipeReferenceDTO? = nil,
        bean: BeanSummaryDTO,
        methodSlug: String,
        equipmentId: UUID? = nil,
        brewedAt: Date,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        ratio: Double? = nil,
        grindSize: GrindSize? = nil,
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
        extractionYieldPercent: Double? = nil,
        flavorNoteSlugs: [String] = [],
        notes: String? = nil,
        photoURL: String? = nil,
        visibility: Visibility = .private,
        createdAt: Date
    ) {
        self.id = id
        self.user = user
        self.recipe = recipe
        self.bean = bean
        self.methodSlug = methodSlug
        self.equipmentId = equipmentId
        self.brewedAt = brewedAt
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.ratio = ratio
        self.grindSize = grindSize
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
        self.extractionYieldPercent = extractionYieldPercent
        self.flavorNoteSlugs = flavorNoteSlugs
        self.notes = notes
        self.photoURL = photoURL
        self.visibility = visibility
        self.createdAt = createdAt
    }
}

/// Body of `POST /me/brews` and `PUT /brews/{id}`.
public struct UpsertBrewLogRequest: Codable, Sendable, Equatable {
    public var recipeId: UUID?
    public var beanId: UUID
    public var methodSlug: String
    public var equipmentId: UUID?
    public var brewedAt: Date
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSize: GrindSize?
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
    public var flavorNoteSlugs: [String]
    public var notes: String?
    /// An image uploaded with `POST /media` by the same member.
    public var photoMediaId: UUID?
    public var visibility: Visibility

    public init(
        recipeId: UUID? = nil,
        beanId: UUID,
        methodSlug: String,
        equipmentId: UUID? = nil,
        brewedAt: Date,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        grindSize: GrindSize? = nil,
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
        flavorNoteSlugs: [String] = [],
        notes: String? = nil,
        photoMediaId: UUID? = nil,
        visibility: Visibility = .private
    ) {
        self.recipeId = recipeId
        self.beanId = beanId
        self.methodSlug = methodSlug
        self.equipmentId = equipmentId
        self.brewedAt = brewedAt
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.grindSize = grindSize
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
        self.flavorNoteSlugs = flavorNoteSlugs
        self.notes = notes
        self.photoMediaId = photoMediaId
        self.visibility = visibility
    }

    /// The fields checked by `BrewRules`.
    public var parameters: BrewParameters {
        BrewParameters(
            brewedAt: brewedAt, doseG: doseG, waterG: waterG, yieldG: yieldG, grindSetting: grindSetting,
            waterTempC: waterTempC, totalTimeS: totalTimeS, rating: rating, acidity: acidity, sweetness: sweetness,
            body: body, bitterness: bitterness, aftertaste: aftertaste, tdsPercent: tdsPercent, notes: notes
        )
    }
}
