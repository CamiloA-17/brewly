import Foundation

/// Registro de una preparación real (la "bitácora" del barista).
public struct Brew: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var recipeID: UUID?
    public var beanID: UUID?
    public var bagID: UUID?
    public var brewMethodID: UUID
    public var grinderID: UUID?
    public var doseG: Decimal
    public var waterG: Decimal?
    public var yieldG: Decimal?
    public var waterTempC: Decimal?
    public var grindSetting: String?
    public var totalTimeS: Int?
    public var tds: Decimal?
    public var extractionPct: Decimal?
    public var rating: Int?
    public var acidity: Int?
    public var sweetness: Int?
    public var body: Int?
    public var bitterness: Int?
    public var aftertaste: Int?
    public var tastingNotes: [String]
    public var notes: String?
    public var visibility: Visibility
    public var brewedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, tds, rating, acidity, sweetness, body, bitterness, aftertaste, notes, visibility
        case ownerID = "owner_id"
        case recipeID = "recipe_id"
        case beanID = "bean_id"
        case bagID = "bag_id"
        case brewMethodID = "brew_method_id"
        case grinderID = "grinder_id"
        case doseG = "dose_g"
        case waterG = "water_g"
        case yieldG = "yield_g"
        case waterTempC = "water_temp_c"
        case grindSetting = "grind_setting"
        case totalTimeS = "total_time_s"
        case extractionPct = "extraction_pct"
        case tastingNotes = "tasting_notes"
        case brewedAt = "brewed_at"
    }

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        recipeID: UUID? = nil,
        beanID: UUID? = nil,
        bagID: UUID? = nil,
        brewMethodID: UUID,
        grinderID: UUID? = nil,
        doseG: Decimal,
        waterG: Decimal? = nil,
        yieldG: Decimal? = nil,
        waterTempC: Decimal? = nil,
        grindSetting: String? = nil,
        totalTimeS: Int? = nil,
        tds: Decimal? = nil,
        extractionPct: Decimal? = nil,
        rating: Int? = nil,
        acidity: Int? = nil,
        sweetness: Int? = nil,
        body: Int? = nil,
        bitterness: Int? = nil,
        aftertaste: Int? = nil,
        tastingNotes: [String] = [],
        notes: String? = nil,
        visibility: Visibility = .private,
        brewedAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.recipeID = recipeID
        self.beanID = beanID
        self.bagID = bagID
        self.brewMethodID = brewMethodID
        self.grinderID = grinderID
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.waterTempC = waterTempC
        self.grindSetting = grindSetting
        self.totalTimeS = totalTimeS
        self.tds = tds
        self.extractionPct = extractionPct
        self.rating = rating
        self.acidity = acidity
        self.sweetness = sweetness
        self.body = body
        self.bitterness = bitterness
        self.aftertaste = aftertaste
        self.tastingNotes = tastingNotes
        self.notes = notes
        self.visibility = visibility
        self.brewedAt = brewedAt
    }

    /// Codifica también los `nil` para poder borrar valores al editar.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(recipeID, forKey: .recipeID)
        try c.encode(beanID, forKey: .beanID)
        try c.encode(bagID, forKey: .bagID)
        try c.encode(brewMethodID, forKey: .brewMethodID)
        try c.encode(grinderID, forKey: .grinderID)
        try c.encode(doseG, forKey: .doseG)
        try c.encode(waterG, forKey: .waterG)
        try c.encode(yieldG, forKey: .yieldG)
        try c.encode(waterTempC, forKey: .waterTempC)
        try c.encode(grindSetting, forKey: .grindSetting)
        try c.encode(totalTimeS, forKey: .totalTimeS)
        try c.encode(tds, forKey: .tds)
        try c.encode(extractionPct, forKey: .extractionPct)
        try c.encode(rating, forKey: .rating)
        try c.encode(acidity, forKey: .acidity)
        try c.encode(sweetness, forKey: .sweetness)
        try c.encode(body, forKey: .body)
        try c.encode(bitterness, forKey: .bitterness)
        try c.encode(aftertaste, forKey: .aftertaste)
        try c.encode(tastingNotes, forKey: .tastingNotes)
        try c.encode(notes, forKey: .notes)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(brewedAt, forKey: .brewedAt)
    }

    /// Crea una preparación a partir de una receta (para el temporizador guiado).
    public init(from recipe: Recipe, ownerID: UUID, bagID: UUID? = nil, elapsed: Int? = nil) {
        self.init(
            ownerID: ownerID,
            recipeID: recipe.id,
            beanID: recipe.ownerID == ownerID ? recipe.beanID : nil,
            bagID: bagID,
            brewMethodID: recipe.brewMethodID,
            grinderID: recipe.ownerID == ownerID ? recipe.grinderID : nil,
            doseG: recipe.doseG,
            waterG: recipe.waterG,
            yieldG: recipe.yieldG,
            waterTempC: recipe.waterTempC,
            grindSetting: recipe.grindSetting,
            totalTimeS: elapsed ?? recipe.totalTimeS
        )
    }
}

public struct BrewStats: Hashable, Codable, Sendable {
    public var totalBrews: Int
    public var totalCoffeeG: Decimal
    public var avgRating: Decimal?
    public var favoriteMethodID: UUID?
    public var favoriteBeanID: UUID?

    enum CodingKeys: String, CodingKey {
        case totalBrews = "total_brews"
        case totalCoffeeG = "total_coffee_g"
        case avgRating = "avg_rating"
        case favoriteMethodID = "favorite_method_id"
        case favoriteBeanID = "favorite_bean_id"
    }

    public init(
        totalBrews: Int = 0,
        totalCoffeeG: Decimal = 0,
        avgRating: Decimal? = nil,
        favoriteMethodID: UUID? = nil,
        favoriteBeanID: UUID? = nil
    ) {
        self.totalBrews = totalBrews
        self.totalCoffeeG = totalCoffeeG
        self.avgRating = avgRating
        self.favoriteMethodID = favoriteMethodID
        self.favoriteBeanID = favoriteBeanID
    }
}
