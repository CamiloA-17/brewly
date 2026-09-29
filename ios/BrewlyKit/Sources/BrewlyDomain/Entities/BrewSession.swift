import Foundation

/// A completed cup, independent of the recipe used to prepare it.
public struct BrewSession: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var recipeID: UUID?
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

    public init(id: UUID, recipeID: UUID?, recipeTitle: String, beanName: String,
                methodSlug: String, doseG: Double, waterG: Double?, yieldG: Double?,
                grindSetting: String?, waterTempC: Double?, elapsedS: Int,
                tdsPercent: Double? = nil, extractionYieldPercent: Double? = nil,
                rating: Int?, acidity: Int?, bitterness: Int?, body: Int?,
                notes: String?, createdAt: Date) {
        self.id = id
        self.recipeID = recipeID
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

public struct BrewSessionDraft: Sendable, Equatable {
    public var recipeID: UUID
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

    public init(recipe: Recipe, elapsedS: Int) {
        recipeID = recipe.id
        doseG = recipe.doseG
        waterG = recipe.waterG
        yieldG = recipe.yieldG
        grindSetting = recipe.grindSetting
        waterTempC = recipe.waterTempC
        self.elapsedS = elapsedS
        tdsPercent = nil
        rating = nil
        acidity = nil
        bitterness = nil
        body = nil
        notes = nil
    }

    public var parameters: BrewSessionParameters {
        BrewSessionParameters(doseG: doseG, waterG: waterG, yieldG: yieldG,
                              grindSetting: grindSetting, waterTempC: waterTempC,
                              elapsedS: elapsedS, tdsPercent: tdsPercent, rating: rating,
                              acidity: acidity, bitterness: bitterness, body: body, notes: notes)
    }
}

/// Suggests one repeatable next action from a user's own observations.
public enum BrewCoach {
    public struct Comparison: Equatable, Sendable {
        public var changedVariables: [String]
        public var ratingChange: Int?

        public init(changedVariables: [String], ratingChange: Int?) {
            self.changedVariables = changedVariables
            self.ratingChange = ratingChange
        }
    }

    public enum Suggestion: Equatable, Sendable {
        case repeatBest
        case tryFinerGrind
        case tryCoarserGrind
        case changeOneVariable
    }

    public static func compare(_ latest: BrewSession, with previous: BrewSession) -> Comparison? {
        guard let recipeID = latest.recipeID, recipeID == previous.recipeID else { return nil }
        var changed: [String] = []
        if latest.doseG != previous.doseG { changed.append("dose") }
        if latest.waterG != previous.waterG { changed.append("water") }
        if latest.yieldG != previous.yieldG { changed.append("yield") }
        if latest.grindSetting != previous.grindSetting { changed.append("grind") }
        if latest.waterTempC != previous.waterTempC { changed.append("temperature") }
        let ratingChange: Int?
        if let a = latest.rating, let b = previous.rating { ratingChange = a - b }
        else { ratingChange = nil }
        return Comparison(changedVariables: changed, ratingChange: ratingChange)
    }

    public static func suggestion(for latest: BrewSession, comparedWith previous: BrewSession? = nil) -> Suggestion? {
        if let previous, let comparison = compare(latest, with: previous),
           comparison.changedVariables.count > 1 {
            return .changeOneVariable
        }
        if let rating = latest.rating, rating >= 4 { return .repeatBest }
        if let acidity = latest.acidity, let bitterness = latest.bitterness {
            if acidity >= 4 && bitterness <= 2 { return .tryFinerGrind }
            if bitterness >= 4 && acidity <= 2 { return .tryCoarserGrind }
        }
        return latest.rating == nil && latest.acidity == nil && latest.bitterness == nil
            ? nil : .changeOneVariable
    }
}
