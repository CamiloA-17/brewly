import Foundation

public struct RecipeStep: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var position: Int
    public var kind: StepKind
    public var instruction: String
    /// Agua a verter en este paso (g).
    public var waterG: Decimal?
    /// Segundo del temporizador en que empieza el paso.
    public var startAtS: Int?
    public var durationS: Int?

    enum CodingKeys: String, CodingKey {
        case id, position, kind, instruction
        case waterG = "water_g"
        case startAtS = "start_at_s"
        case durationS = "duration_s"
    }

    public init(
        id: UUID = UUID(),
        position: Int = 0,
        kind: StepKind = .pour,
        instruction: String = "",
        waterG: Decimal? = nil,
        startAtS: Int? = nil,
        durationS: Int? = nil
    ) {
        self.id = id
        self.position = position
        self.kind = kind
        self.instruction = instruction
        self.waterG = waterG
        self.startAtS = startAtS
        self.durationS = durationS
    }
}

public struct Recipe: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var title: String
    public var description: String?
    public var brewMethodID: UUID
    public var beanID: UUID?
    public var grinderID: UUID?
    public var brewerID: UUID?
    public var doseG: Decimal
    public var waterG: Decimal?
    public var yieldG: Decimal?
    public var waterTempC: Decimal?
    public var grindSize: String?
    public var grindSetting: String?
    public var totalTimeS: Int?
    public var forkedFromID: UUID?
    public var visibility: Visibility
    public var createdAt: Date

    // Relaciones embebidas (solo lectura; vienen del `select` de PostgREST).
    public var ratio: Decimal?
    public var method: BrewMethod?
    public var bean: CoffeeBean?
    public var steps: [RecipeStep]

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility, ratio, method, bean, steps
        case ownerID = "owner_id"
        case brewMethodID = "brew_method_id"
        case beanID = "bean_id"
        case grinderID = "grinder_id"
        case brewerID = "brewer_id"
        case doseG = "dose_g"
        case waterG = "water_g"
        case yieldG = "yield_g"
        case waterTempC = "water_temp_c"
        case grindSize = "grind_size"
        case grindSetting = "grind_setting"
        case totalTimeS = "total_time_s"
        case forkedFromID = "forked_from_id"
        case createdAt = "created_at"
    }

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        title: String = "",
        description: String? = nil,
        brewMethodID: UUID,
        beanID: UUID? = nil,
        grinderID: UUID? = nil,
        brewerID: UUID? = nil,
        doseG: Decimal = 15,
        waterG: Decimal? = 250,
        yieldG: Decimal? = nil,
        waterTempC: Decimal? = 94,
        grindSize: String? = nil,
        grindSetting: String? = nil,
        totalTimeS: Int? = nil,
        forkedFromID: UUID? = nil,
        visibility: Visibility = .private,
        createdAt: Date = .now,
        method: BrewMethod? = nil,
        bean: CoffeeBean? = nil,
        steps: [RecipeStep] = []
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.description = description
        self.brewMethodID = brewMethodID
        self.beanID = beanID
        self.grinderID = grinderID
        self.brewerID = brewerID
        self.doseG = doseG
        self.waterG = waterG
        self.yieldG = yieldG
        self.waterTempC = waterTempC
        self.grindSize = grindSize
        self.grindSetting = grindSetting
        self.totalTimeS = totalTimeS
        self.forkedFromID = forkedFromID
        self.visibility = visibility
        self.createdAt = createdAt
        self.method = method
        self.bean = bean
        self.steps = steps
        self.ratio = BrewMath.ratio(dose: doseG, water: waterG)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerID = try c.decode(UUID.self, forKey: .ownerID)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        brewMethodID = try c.decode(UUID.self, forKey: .brewMethodID)
        beanID = try c.decodeIfPresent(UUID.self, forKey: .beanID)
        grinderID = try c.decodeIfPresent(UUID.self, forKey: .grinderID)
        brewerID = try c.decodeIfPresent(UUID.self, forKey: .brewerID)
        doseG = try c.decode(Decimal.self, forKey: .doseG)
        waterG = try c.decodeIfPresent(Decimal.self, forKey: .waterG)
        yieldG = try c.decodeIfPresent(Decimal.self, forKey: .yieldG)
        waterTempC = try c.decodeIfPresent(Decimal.self, forKey: .waterTempC)
        grindSize = try c.decodeIfPresent(String.self, forKey: .grindSize)
        grindSetting = try c.decodeIfPresent(String.self, forKey: .grindSetting)
        totalTimeS = try c.decodeIfPresent(Int.self, forKey: .totalTimeS)
        forkedFromID = try c.decodeIfPresent(UUID.self, forKey: .forkedFromID)
        visibility = try c.decode(Visibility.self, forKey: .visibility)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        ratio = try c.decodeIfPresent(Decimal.self, forKey: .ratio)
        method = try c.decodeIfPresent(BrewMethod.self, forKey: .method)
        bean = try c.decodeIfPresent(CoffeeBean.self, forKey: .bean)
        steps = (try c.decodeIfPresent([RecipeStep].self, forKey: .steps) ?? [])
            .sorted { $0.position < $1.position }
    }

    /// Solo se codifican las columnas escribibles (sin relaciones ni `ratio`,
    /// que es una columna generada en la base de datos).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(brewMethodID, forKey: .brewMethodID)
        try c.encode(beanID, forKey: .beanID)
        try c.encode(grinderID, forKey: .grinderID)
        try c.encode(brewerID, forKey: .brewerID)
        try c.encode(doseG, forKey: .doseG)
        try c.encode(waterG, forKey: .waterG)
        try c.encode(yieldG, forKey: .yieldG)
        try c.encode(waterTempC, forKey: .waterTempC)
        try c.encode(grindSize, forKey: .grindSize)
        try c.encode(grindSetting, forKey: .grindSetting)
        try c.encode(totalTimeS, forKey: .totalTimeS)
        try c.encode(forkedFromID, forKey: .forkedFromID)
        try c.encode(visibility, forKey: .visibility)
    }

    /// Relación calculada localmente (útil mientras se edita, antes de guardar).
    public var computedRatio: Decimal? { BrewMath.ratio(dose: doseG, water: waterG) }
}
