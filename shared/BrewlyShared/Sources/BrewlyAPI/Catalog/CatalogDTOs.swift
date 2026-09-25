import BrewlyCore

/// Every global catalog, returned at once by `GET /catalog`.
public struct CatalogDTO: Codable, Sendable, Equatable {
    public var brewMethods: [BrewMethodDTO]
    public var varietals: [VarietalDTO]
    public var processingMethods: [ProcessingMethodDTO]
    public var countries: [CountryDTO]
    public var grinders: [GrinderDTO]
    public var flavorNotes: [FlavorNoteDTO]

    public init(
        brewMethods: [BrewMethodDTO],
        varietals: [VarietalDTO],
        processingMethods: [ProcessingMethodDTO],
        countries: [CountryDTO],
        grinders: [GrinderDTO],
        flavorNotes: [FlavorNoteDTO]
    ) {
        self.brewMethods = brewMethods
        self.varietals = varietals
        self.processingMethods = processingMethods
        self.countries = countries
        self.grinders = grinders
        self.flavorNotes = flavorNotes
    }
}

public struct BrewMethodDTO: Codable, Sendable, Equatable, Hashable {
    public var slug: String
    public var name: String
    public var category: MethodCategory
    public var ratioBasis: RatioBasis
    public var description: String?
    public var defaultRatio: Double?
    public var defaultGrindSize: GrindSize?
    public var defaultWaterTempC: Double?

    public init(
        slug: String,
        name: String,
        category: MethodCategory,
        ratioBasis: RatioBasis,
        description: String? = nil,
        defaultRatio: Double? = nil,
        defaultGrindSize: GrindSize? = nil,
        defaultWaterTempC: Double? = nil
    ) {
        self.slug = slug
        self.name = name
        self.category = category
        self.ratioBasis = ratioBasis
        self.description = description
        self.defaultRatio = defaultRatio
        self.defaultGrindSize = defaultGrindSize
        self.defaultWaterTempC = defaultWaterTempC
    }
}

public struct VarietalDTO: Codable, Sendable, Equatable, Hashable {
    public var slug: String
    public var name: String
    public var species: CoffeeSpecies

    public init(slug: String, name: String, species: CoffeeSpecies) {
        self.slug = slug
        self.name = name
        self.species = species
    }
}

public struct ProcessingMethodDTO: Codable, Sendable, Equatable, Hashable {
    public var slug: String
    public var name: String
    public var description: String?

    public init(slug: String, name: String, description: String? = nil) {
        self.slug = slug
        self.name = name
        self.description = description
    }
}

public struct CountryDTO: Codable, Sendable, Equatable, Hashable {
    /// ISO 3166-1 alpha-2 code.
    public var code: String
    public var name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct GrinderDTO: Codable, Sendable, Equatable, Hashable {
    public var slug: String
    public var brand: String
    public var model: String
    public var kind: GrinderKind
    public var burrType: BurrType?

    public init(slug: String, brand: String, model: String, kind: GrinderKind, burrType: BurrType? = nil) {
        self.slug = slug
        self.brand = brand
        self.model = model
        self.kind = kind
        self.burrType = burrType
    }
}

public struct FlavorNoteDTO: Codable, Sendable, Equatable, Hashable {
    public var slug: String
    public var name: String
    public var category: FlavorCategory

    public init(slug: String, name: String, category: FlavorCategory) {
        self.slug = slug
        self.name = name
        self.category = category
    }
}

/// Brew methods the signed-in user owns or uses (`GET /me/methods`).
public struct UserMethodsDTO: Codable, Sendable, Equatable {
    public var methodSlugs: [String]

    public init(methodSlugs: [String]) {
        self.methodSlugs = methodSlugs
    }
}
