import Foundation

/// Ficha de un café (origen, proceso, tueste, notas).
public struct CoffeeBean: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var roaster: String?
    public var originCountry: String?
    public var region: String?
    public var farm: String?
    public var producer: String?
    public var varieties: [String]
    public var process: CoffeeProcess?
    public var altitudeMinM: Int?
    public var altitudeMaxM: Int?
    public var roastLevel: RoastLevel?
    public var tastingNotes: [String]
    public var scaScore: Decimal?
    public var photoPath: String?
    public var notes: String?
    public var visibility: Visibility
    public var archivedAt: Date?
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, roaster, region, farm, producer, varieties, process, notes, visibility
        case ownerID = "owner_id"
        case originCountry = "origin_country"
        case altitudeMinM = "altitude_min_m"
        case altitudeMaxM = "altitude_max_m"
        case roastLevel = "roast_level"
        case tastingNotes = "tasting_notes"
        case scaScore = "sca_score"
        case photoPath = "photo_path"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
    }

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        name: String = "",
        roaster: String? = nil,
        originCountry: String? = nil,
        region: String? = nil,
        farm: String? = nil,
        producer: String? = nil,
        varieties: [String] = [],
        process: CoffeeProcess? = nil,
        altitudeMinM: Int? = nil,
        altitudeMaxM: Int? = nil,
        roastLevel: RoastLevel? = nil,
        tastingNotes: [String] = [],
        scaScore: Decimal? = nil,
        photoPath: String? = nil,
        notes: String? = nil,
        visibility: Visibility = .private,
        archivedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.roaster = roaster
        self.originCountry = originCountry
        self.region = region
        self.farm = farm
        self.producer = producer
        self.varieties = varieties
        self.process = process
        self.altitudeMinM = altitudeMinM
        self.altitudeMaxM = altitudeMaxM
        self.roastLevel = roastLevel
        self.tastingNotes = tastingNotes
        self.scaScore = scaScore
        self.photoPath = photoPath
        self.notes = notes
        self.visibility = visibility
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    /// Se codifican también los `nil` para que al editar se puedan borrar campos
    /// (el encoder sintetizado omite las claves nulas y el upsert las ignoraría).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(name, forKey: .name)
        try c.encode(roaster, forKey: .roaster)
        try c.encode(originCountry, forKey: .originCountry)
        try c.encode(region, forKey: .region)
        try c.encode(farm, forKey: .farm)
        try c.encode(producer, forKey: .producer)
        try c.encode(varieties, forKey: .varieties)
        try c.encode(process, forKey: .process)
        try c.encode(altitudeMinM, forKey: .altitudeMinM)
        try c.encode(altitudeMaxM, forKey: .altitudeMaxM)
        try c.encode(roastLevel, forKey: .roastLevel)
        try c.encode(tastingNotes, forKey: .tastingNotes)
        try c.encode(scaScore, forKey: .scaScore)
        try c.encode(photoPath, forKey: .photoPath)
        try c.encode(notes, forKey: .notes)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(archivedAt, forKey: .archivedAt)
    }

    public var originSummary: String {
        [originCountry, region].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Bolsa física de un café: inventario siempre privado.
public struct BeanBag: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var beanID: UUID
    public var ownerID: UUID
    public var roastDate: Date?
    public var purchaseDate: Date?
    public var openedAt: Date?
    public var weightG: Decimal
    public var remainingG: Decimal
    public var price: Decimal?
    public var currency: String?
    public var isFrozen: Bool
    public var finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, price, currency
        case beanID = "bean_id"
        case ownerID = "owner_id"
        case roastDate = "roast_date"
        case purchaseDate = "purchase_date"
        case openedAt = "opened_at"
        case weightG = "weight_g"
        case remainingG = "remaining_g"
        case isFrozen = "is_frozen"
        case finishedAt = "finished_at"
    }

    public init(
        id: UUID = UUID(),
        beanID: UUID,
        ownerID: UUID,
        roastDate: Date? = nil,
        purchaseDate: Date? = nil,
        openedAt: Date? = nil,
        weightG: Decimal = 250,
        remainingG: Decimal? = nil,
        price: Decimal? = nil,
        currency: String? = nil,
        isFrozen: Bool = false,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.beanID = beanID
        self.ownerID = ownerID
        self.roastDate = roastDate
        self.purchaseDate = purchaseDate
        self.openedAt = openedAt
        self.weightG = weightG
        self.remainingG = remainingG ?? weightG
        self.price = price
        self.currency = currency
        self.isFrozen = isFrozen
        self.finishedAt = finishedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        beanID = try c.decode(UUID.self, forKey: .beanID)
        ownerID = try c.decode(UUID.self, forKey: .ownerID)
        roastDate = try c.decodeIfPresent(CalendarDay.self, forKey: .roastDate)?.date
        purchaseDate = try c.decodeIfPresent(CalendarDay.self, forKey: .purchaseDate)?.date
        openedAt = try c.decodeIfPresent(CalendarDay.self, forKey: .openedAt)?.date
        weightG = try c.decode(Decimal.self, forKey: .weightG)
        remainingG = try c.decode(Decimal.self, forKey: .remainingG)
        price = try c.decodeIfPresent(Decimal.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        isFrozen = try c.decodeIfPresent(Bool.self, forKey: .isFrozen) ?? false
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
    }

    /// Las columnas `date` se envían como `yyyy-MM-dd` en la zona horaria local
    /// para que el día no cambie al convertir a UTC.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(beanID, forKey: .beanID)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(roastDate.map(CalendarDay.init), forKey: .roastDate)
        try c.encode(purchaseDate.map(CalendarDay.init), forKey: .purchaseDate)
        try c.encode(openedAt.map(CalendarDay.init), forKey: .openedAt)
        try c.encode(weightG, forKey: .weightG)
        try c.encode(remainingG, forKey: .remainingG)
        try c.encode(price, forKey: .price)
        try c.encode(currency, forKey: .currency)
        try c.encode(isFrozen, forKey: .isFrozen)
        try c.encode(finishedAt, forKey: .finishedAt)
    }

    /// Días desde el tueste (útil para saber si el café está "en su punto").
    public func daysSinceRoast(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let roastDate else { return nil }
        return calendar.dateComponents([.day], from: roastDate, to: now).day
    }

    /// Fracción restante entre 0 y 1.
    public var remainingFraction: Double {
        guard weightG > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: remainingG / weightG).doubleValue
        return min(max(value, 0), 1)
    }
}

public struct Equipment: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var type: EquipmentType
    public var brand: String
    public var model: String?
    public var notes: String?
    public var visibility: Visibility

    enum CodingKeys: String, CodingKey {
        case id, type, brand, model, notes, visibility
        case ownerID = "owner_id"
    }

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        type: EquipmentType,
        brand: String,
        model: String? = nil,
        notes: String? = nil,
        visibility: Visibility = .private
    ) {
        self.id = id
        self.ownerID = ownerID
        self.type = type
        self.brand = brand
        self.model = model
        self.notes = notes
        self.visibility = visibility
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(type, forKey: .type)
        try c.encode(brand, forKey: .brand)
        try c.encode(model, forKey: .model)
        try c.encode(notes, forKey: .notes)
        try c.encode(visibility, forKey: .visibility)
    }

    public var displayName: String { [brand, model].compactMap { $0 }.joined(separator: " ") }
}

public struct BrewMethod: Identifiable, Hashable, Codable, Sendable {
    public struct DefaultParams: Hashable, Codable, Sendable {
        public var doseG: Decimal?
        public var waterG: Decimal?
        public var yieldG: Decimal?
        public var tempC: Decimal?
        public var timeS: Int?

        enum CodingKeys: String, CodingKey {
            case doseG = "dose_g"
            case waterG = "water_g"
            case yieldG = "yield_g"
            case tempC = "temp_c"
            case timeS = "time_s"
        }

        public init(
            doseG: Decimal? = nil,
            waterG: Decimal? = nil,
            yieldG: Decimal? = nil,
            tempC: Decimal? = nil,
            timeS: Int? = nil
        ) {
            self.doseG = doseG
            self.waterG = waterG
            self.yieldG = yieldG
            self.tempC = tempC
            self.timeS = timeS
        }
    }

    public var id: UUID
    /// `nil` para los métodos del catálogo del sistema.
    public var ownerID: UUID?
    public var slug: String
    public var name: String
    public var category: BrewCategory
    public var description: String?
    public var icon: String?
    public var defaultParams: DefaultParams

    enum CodingKeys: String, CodingKey {
        case id, slug, name, category, description, icon
        case ownerID = "owner_id"
        case defaultParams = "default_params"
    }

    public init(
        id: UUID = UUID(),
        ownerID: UUID? = nil,
        slug: String,
        name: String,
        category: BrewCategory,
        description: String? = nil,
        icon: String? = nil,
        defaultParams: DefaultParams = .init()
    ) {
        self.id = id
        self.ownerID = ownerID
        self.slug = slug
        self.name = name
        self.category = category
        self.description = description
        self.icon = icon
        self.defaultParams = defaultParams
    }

    public var isSystem: Bool { ownerID == nil }
}
