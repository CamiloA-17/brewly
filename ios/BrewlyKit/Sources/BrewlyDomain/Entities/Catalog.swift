import Foundation

public struct BrewMethod: Identifiable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var category: MethodCategory
    public var ratioBasis: RatioBasis
    public var description: String?
    public var defaultRatio: Double?
    public var defaultGrindSize: GrindSize?
    public var defaultWaterTempC: Double?

    public var id: String { slug }

    /// Espresso-like methods also record brew pressure.
    public var usesPressure: Bool { category == .espresso || category == .pressure }

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

public struct Varietal: Identifiable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var species: CoffeeSpecies
    public var id: String { slug }

    public init(slug: String, name: String, species: CoffeeSpecies) {
        self.slug = slug
        self.name = name
        self.species = species
    }
}

public struct ProcessingMethod: Identifiable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var description: String?
    public var id: String { slug }

    public init(slug: String, name: String, description: String? = nil) {
        self.slug = slug
        self.name = name
        self.description = description
    }
}

public struct Country: Identifiable, Hashable, Sendable {
    /// ISO 3166-1 alpha-2 code.
    public var code: String
    public var name: String
    public var id: String { code }

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct Grinder: Identifiable, Hashable, Sendable {
    public var slug: String
    public var brand: String
    public var model: String
    public var kind: GrinderKind
    public var burrType: BurrType?
    public var id: String { slug }
    public var displayName: String { "\(brand) \(model)" }

    public init(slug: String, brand: String, model: String, kind: GrinderKind, burrType: BurrType? = nil) {
        self.slug = slug
        self.brand = brand
        self.model = model
        self.kind = kind
        self.burrType = burrType
    }
}

public struct FlavorNote: Identifiable, Hashable, Sendable {
    public var slug: String
    public var name: String
    public var category: FlavorCategory
    public var id: String { slug }

    public init(slug: String, name: String, category: FlavorCategory) {
        self.slug = slug
        self.name = name
        self.category = category
    }
}

/// Every global catalog. Beans and recipes reference catalog items by slug (or ISO code).
public struct Catalog: Hashable, Sendable {
    public var brewMethods: [BrewMethod]
    public var varietals: [Varietal]
    public var processingMethods: [ProcessingMethod]
    public var countries: [Country]
    public var grinders: [Grinder]
    public var flavorNotes: [FlavorNote]

    public init(
        brewMethods: [BrewMethod] = [],
        varietals: [Varietal] = [],
        processingMethods: [ProcessingMethod] = [],
        countries: [Country] = [],
        grinders: [Grinder] = [],
        flavorNotes: [FlavorNote] = []
    ) {
        self.brewMethods = brewMethods
        self.varietals = varietals
        self.processingMethods = processingMethods
        self.countries = countries
        self.grinders = grinders
        self.flavorNotes = flavorNotes
    }

    public static let empty = Catalog()

    public func brewMethod(_ slug: String?) -> BrewMethod? {
        guard let slug else { return nil }
        return brewMethods.first { $0.slug == slug }
    }

    public func varietal(_ slug: String) -> Varietal? {
        varietals.first { $0.slug == slug }
    }

    public func processingMethod(_ slug: String?) -> ProcessingMethod? {
        guard let slug else { return nil }
        return processingMethods.first { $0.slug == slug }
    }

    public func country(_ code: String?) -> Country? {
        guard let code else { return nil }
        return countries.first { $0.code == code }
    }

    public func grinder(_ slug: String?) -> Grinder? {
        guard let slug else { return nil }
        return grinders.first { $0.slug == slug }
    }

    public func flavorNote(_ slug: String) -> FlavorNote? {
        flavorNotes.first { $0.slug == slug }
    }
}
