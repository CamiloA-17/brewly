import Foundation

public struct RecipeStep: Hashable, Sendable {
    public var position: Int
    public var kind: BrewStepKind
    public var startS: Int
    public var waterTargetG: Double?
    public var instruction: String?

    public init(position: Int, kind: BrewStepKind, startS: Int, waterTargetG: Double? = nil, instruction: String? = nil) {
        self.position = position
        self.kind = kind
        self.startS = startS
        self.waterTargetG = waterTargetG
        self.instruction = instruction
    }
}

/// A recipe (a preparation): every parameter needed to reproduce a cup.
public struct Recipe: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var author: UserSummary
    public var bean: BeanSummary
    public var methodSlug: String
    public var forkedFromID: UUID?
    public var title: String
    public var description: String?
    public var doseG: Double
    public var waterG: Double?
    public var yieldG: Double?
    public var ratio: Double
    public var grindSize: GrindSize
    public var grinderSlug: String?
    public var grindSetting: String?
    public var grindMicrons: Int?
    public var waterTempC: Double?
    public var bloomWaterG: Double?
    public var bloomTimeS: Int?
    public var totalTimeS: Int?
    public var pressureBar: Double?
    public var filterType: FilterType?
    public var waterProfile: String?
    public var waterTdsPpm: Int?
    public var tdsPercent: Double?
    public var extractionYieldPercent: Double?
    public var rating: Int?
    public var notes: String?
    public var flavorNoteSlugs: [String]
    public var steps: [RecipeStep]
    public var visibility: Visibility
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        author: UserSummary,
        bean: BeanSummary,
        methodSlug: String,
        forkedFromID: UUID? = nil,
        title: String,
        description: String? = nil,
        doseG: Double,
        waterG: Double? = nil,
        yieldG: Double? = nil,
        ratio: Double,
        grindSize: GrindSize,
        grinderSlug: String? = nil,
        grindSetting: String? = nil,
        grindMicrons: Int? = nil,
        waterTempC: Double? = nil,
        bloomWaterG: Double? = nil,
        bloomTimeS: Int? = nil,
        totalTimeS: Int? = nil,
        pressureBar: Double? = nil,
        filterType: FilterType? = nil,
        waterProfile: String? = nil,
        waterTdsPpm: Int? = nil,
        tdsPercent: Double? = nil,
        extractionYieldPercent: Double? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        flavorNoteSlugs: [String] = [],
        steps: [RecipeStep] = [],
        visibility: Visibility = .public,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.bean = bean
        self.methodSlug = methodSlug
        self.forkedFromID = forkedFromID
        self.title = title
        self.description = description
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.ratio = ratio
        self.grindSize = grindSize
        self.grinderSlug = grinderSlug
        self.grindSetting = grindSetting
        self.grindMicrons = grindMicrons
        self.waterTempC = waterTempC
        self.bloomWaterG = bloomWaterG
        self.bloomTimeS = bloomTimeS
        self.totalTimeS = totalTimeS
        self.pressureBar = pressureBar
        self.filterType = filterType
        self.waterProfile = waterProfile
        self.waterTdsPpm = waterTdsPpm
        self.tdsPercent = tdsPercent
        self.extractionYieldPercent = extractionYieldPercent
        self.rating = rating
        self.notes = notes
        self.flavorNoteSlugs = flavorNoteSlugs
        self.steps = steps
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Compact recipe for lists.
public struct RecipeSummary: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var author: UserSummary
    public var beanName: String
    public var methodSlug: String
    public var title: String
    public var doseG: Double
    public var ratio: Double
    public var grindSize: GrindSize
    public var waterTempC: Double?
    public var totalTimeS: Int?
    public var rating: Int?
    public var visibility: Visibility
    public var createdAt: Date

    public init(
        id: UUID,
        author: UserSummary,
        beanName: String,
        methodSlug: String,
        title: String,
        doseG: Double,
        ratio: Double,
        grindSize: GrindSize,
        waterTempC: Double? = nil,
        totalTimeS: Int? = nil,
        rating: Int? = nil,
        visibility: Visibility = .public,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.beanName = beanName
        self.methodSlug = methodSlug
        self.title = title
        self.doseG = doseG
        self.ratio = ratio
        self.grindSize = grindSize
        self.waterTempC = waterTempC
        self.totalTimeS = totalTimeS
        self.rating = rating
        self.visibility = visibility
        self.createdAt = createdAt
    }
}

/// Filters for exploring the community's public recipes.
public struct RecipeFilter: Hashable, Sendable {
    public var methodSlug: String?
    public var countryCode: String?
    public var varietalSlug: String?

    public init(methodSlug: String? = nil, countryCode: String? = nil, varietalSlug: String? = nil) {
        self.methodSlug = methodSlug
        self.countryCode = countryCode
        self.varietalSlug = varietalSlug
    }
}

/// A page of results with an opaque cursor for the next one.
public struct PagedResult<Item: Sendable>: Sendable {
    public var items: [Item]
    public var nextCursor: String?

    public init(items: [Item], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
