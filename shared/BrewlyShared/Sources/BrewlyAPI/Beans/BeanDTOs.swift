import BrewlyCore
import Foundation

/// A coffee bean owned by a user. Catalog references are slugs/ISO codes.
public struct BeanDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var ownerId: UUID
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
    public var isDecaf: Bool
    public var notes: String?
    public var photoURL: String?
    public var visibility: Visibility
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        ownerId: UUID,
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
        isDecaf: Bool = false,
        notes: String? = nil,
        photoURL: String? = nil,
        visibility: Visibility = .public,
        isArchived: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerId = ownerId
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
        self.isDecaf = isDecaf
        self.notes = notes
        self.photoURL = photoURL
        self.visibility = visibility
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Short bean description embedded in recipes.
public struct BeanSummaryDTO: Codable, Sendable, Equatable, Hashable {
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

/// Body of `POST /beans` and `PUT /beans/{id}`.
public struct UpsertBeanRequest: Codable, Sendable, Equatable {
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
    public var isDecaf: Bool
    public var notes: String?
    public var visibility: Visibility
    public var isArchived: Bool

    public init(
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
        isDecaf: Bool = false,
        notes: String? = nil,
        visibility: Visibility = .public,
        isArchived: Bool = false
    ) {
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
        self.isDecaf = isDecaf
        self.notes = notes
        self.visibility = visibility
        self.isArchived = isArchived
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
            notes: notes
        )
    }
}
