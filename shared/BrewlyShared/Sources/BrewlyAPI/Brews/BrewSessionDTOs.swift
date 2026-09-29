import BrewlyCore
import Foundation

/// An actual preparation. Values are snapshots, so editing a recipe does not rewrite history.
public struct BrewSessionDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var recipeId: UUID?
    public var recipeTitle: String
    public var beanName: String
    public var methodSlug: String
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var grindSetting: String?
    public var waterTempC: Double?
    public var elapsedS: Int
    public var tdsPercent: Double?
    public var extractionYieldPercent: Double?
    public var rating: Int?
    public var acidity: Int?
    public var bitterness: Int?
    public var body: Int?
    public var notes: String?
    public var createdAt: Date

    public init(id: UUID, recipeId: UUID?, recipeTitle: String, beanName: String,
                methodSlug: String, doseG: Double, waterG: Double?, yieldG: Double?,
                grindSetting: String?, waterTempC: Double?, elapsedS: Int,
                tdsPercent: Double?, extractionYieldPercent: Double?, rating: Int?,
                acidity: Int?, bitterness: Int?, body: Int?, notes: String?, createdAt: Date) {
        self.id = id
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.beanName = beanName
        self.methodSlug = methodSlug
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.grindSetting = grindSetting
        self.waterTempC = waterTempC
        self.elapsedS = elapsedS
        self.tdsPercent = tdsPercent
        self.extractionYieldPercent = extractionYieldPercent
        self.rating = rating
        self.acidity = acidity
        self.bitterness = bitterness
        self.body = body
        self.notes = notes
        self.createdAt = createdAt
    }
}

public struct CreateBrewSessionRequest: Codable, Sendable, Equatable {
    public var recipeId: UUID
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

    public init(recipeId: UUID, doseG: Double, waterG: Double?, yieldG: Double?,
                grindSetting: String?, waterTempC: Double?, elapsedS: Int,
                tdsPercent: Double?, rating: Int?,
                acidity: Int?, bitterness: Int?, body: Int?, notes: String?) {
        self.recipeId = recipeId
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

    public var parameters: BrewSessionParameters {
        BrewSessionParameters(doseG: doseG, waterG: waterG, yieldG: yieldG,
                              grindSetting: grindSetting, waterTempC: waterTempC,
                              elapsedS: elapsedS, tdsPercent: tdsPercent, rating: rating,
                              acidity: acidity, bitterness: bitterness, body: body, notes: notes)
    }
}
