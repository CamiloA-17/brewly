import Foundation

/// A coffee owned by the user (usually one bag).
public struct Bean: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var roaster: String?
    public var countryCode: String?
    public var region: String?
    public var farm: String?
    public var producer: String?
    public var altitudeMinM: Int?
    public var altitudeMaxM: Int?
    public var processingMethodSlug: String?
    public var varietalSlugs: [String]
    public var flavorNoteSlugs: [String]
    public var roastLevel: RoastLevel?
    public var roastDate: CalendarDate?
    public var harvestYear: Int?
    public var scaScore: Double?
    public var weightG: Int?
    /// Coffee left in the bag; each brew subtracts its dose.
    public var remainingG: Double?
    public var isDecaf: Bool
    public var notes: String?
    public var photoURL: URL?
    public var purchaseDate: CalendarDate?
    public var openedDate: CalendarDate?
    public var price: Double?
    /// ISO 4217 code of `price`.
    public var currency: String?
    public var lot: String?
    public var isFavorite: Bool
    public var visibility: Visibility
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        ownerID: UUID,
        name: String,
        roaster: String? = nil,
        countryCode: String? = nil,
        region: String? = nil,
        farm: String? = nil,
        producer: String? = nil,
        altitudeMinM: Int? = nil,
        altitudeMaxM: Int? = nil,
        processingMethodSlug: String? = nil,
        varietalSlugs: [String] = [],
        flavorNoteSlugs: [String] = [],
        roastLevel: RoastLevel? = nil,
        roastDate: CalendarDate? = nil,
        harvestYear: Int? = nil,
        scaScore: Double? = nil,
        weightG: Int? = nil,
        remainingG: Double? = nil,
        isDecaf: Bool = false,
        notes: String? = nil,
        photoURL: URL? = nil,
        purchaseDate: CalendarDate? = nil,
        openedDate: CalendarDate? = nil,
        price: Double? = nil,
        currency: String? = nil,
        lot: String? = nil,
        isFavorite: Bool = false,
        visibility: Visibility = .public,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.roaster = roaster
        self.countryCode = countryCode
        self.region = region
        self.farm = farm
        self.producer = producer
        self.altitudeMinM = altitudeMinM
        self.altitudeMaxM = altitudeMaxM
        self.processingMethodSlug = processingMethodSlug
        self.varietalSlugs = varietalSlugs
        self.flavorNoteSlugs = flavorNoteSlugs
        self.roastLevel = roastLevel
        self.roastDate = roastDate
        self.harvestYear = harvestYear
        self.scaScore = scaScore
        self.weightG = weightG
        self.remainingG = remainingG
        self.isDecaf = isDecaf
        self.notes = notes
        self.photoURL = photoURL
        self.purchaseDate = purchaseDate
        self.openedDate = openedDate
        self.price = price
        self.currency = currency
        self.lot = lot
        self.isFavorite = isFavorite
        self.visibility = visibility
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Days since roasting ("rest days"), when the roast date is known.
    public func daysSinceRoast(today: CalendarDate = .today()) -> Int? {
        roastDate.map { $0.days(until: today) }
    }
}

/// Short bean description embedded in recipes.
public struct BeanSummary: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var roaster: String?
    public var countryCode: String?
    public var farm: String?
    public var processingMethodSlug: String?
    public var varietalSlugs: [String]
    public var roastLevel: RoastLevel?

    public init(
        id: UUID,
        name: String,
        roaster: String? = nil,
        countryCode: String? = nil,
        farm: String? = nil,
        processingMethodSlug: String? = nil,
        varietalSlugs: [String] = [],
        roastLevel: RoastLevel? = nil
    ) {
        self.id = id
        self.name = name
        self.roaster = roaster
        self.countryCode = countryCode
        self.farm = farm
        self.processingMethodSlug = processingMethodSlug
        self.varietalSlugs = varietalSlugs
        self.roastLevel = roastLevel
    }
}

/// Editable state of a bean form.
public struct BeanDraft: Hashable, Sendable {
    public var name = ""
    public var roaster = ""
    public var countryCode: String?
    public var region = ""
    public var farm = ""
    public var producer = ""
    public var altitudeMinM: Int?
    public var altitudeMaxM: Int?
    public var processingMethodSlug: String?
    public var varietalSlugs: Set<String> = []
    public var flavorNoteSlugs: Set<String> = []
    public var roastLevel: RoastLevel?
    public var roastDate: CalendarDate?
    public var harvestYear: Int?
    public var scaScore: Double?
    public var weightG: Int?
    /// Coffee left in the bag; each brew subtracts its dose.
    public var remainingG: Double?
    public var isDecaf = false
    public var notes = ""
    public var purchaseDate: CalendarDate?
    public var openedDate: CalendarDate?
    public var price: Double?
    public var currency: String?
    public var lot = ""
    public var isFavorite = false
    /// The current photo; `nil` removes it when saving.
    public var photoURL: URL?
    /// A newly picked photo, uploaded when saving.
    public var newPhotoData: Data?
    public var visibility: Visibility = .public
    public var isArchived = false

    public init() {}

    public init(bean: Bean) {
        name = bean.name
        roaster = bean.roaster ?? ""
        countryCode = bean.countryCode
        region = bean.region ?? ""
        farm = bean.farm ?? ""
        producer = bean.producer ?? ""
        altitudeMinM = bean.altitudeMinM
        altitudeMaxM = bean.altitudeMaxM
        processingMethodSlug = bean.processingMethodSlug
        varietalSlugs = Set(bean.varietalSlugs)
        flavorNoteSlugs = Set(bean.flavorNoteSlugs)
        roastLevel = bean.roastLevel
        roastDate = bean.roastDate
        harvestYear = bean.harvestYear
        scaScore = bean.scaScore
        weightG = bean.weightG
        remainingG = bean.remainingG
        isDecaf = bean.isDecaf
        notes = bean.notes ?? ""
        purchaseDate = bean.purchaseDate
        openedDate = bean.openedDate
        price = bean.price
        currency = bean.currency
        lot = bean.lot ?? ""
        isFavorite = bean.isFavorite
        photoURL = bean.photoURL
        visibility = bean.visibility
        isArchived = bean.isArchived
    }

    /// The fields checked by `BeanRules`.
    public var parameters: BeanParameters {
        BeanParameters(
            name: name,
            roaster: roaster,
            region: region,
            farm: farm,
            producer: producer,
            altitudeMinM: altitudeMinM,
            altitudeMaxM: altitudeMaxM,
            roastDate: roastDate,
            harvestYear: harvestYear,
            scaScore: scaScore,
            weightG: weightG,
            remainingG: remainingG,
            purchaseDate: purchaseDate,
            openedDate: openedDate,
            price: price,
            currency: currency,
            lot: lot,
            notes: notes
        )
    }
}
