/// Bean fields checked by `BeanRules`.
public struct BeanParameters: Hashable, Sendable {
    public var name: String
    public var roaster: String?
    public var region: String?
    public var farm: String?
    public var producer: String?
    public var altitudeMinM: Int?
    public var altitudeMaxM: Int?
    public var roastDate: CalendarDate?
    public var harvestYear: Int?
    public var scaScore: Double?
    public var weightG: Int?
    public var remainingG: Double?
    public var notes: String?

    public init(
        name: String,
        roaster: String? = nil,
        region: String? = nil,
        farm: String? = nil,
        producer: String? = nil,
        altitudeMinM: Int? = nil,
        altitudeMaxM: Int? = nil,
        roastDate: CalendarDate? = nil,
        harvestYear: Int? = nil,
        scaScore: Double? = nil,
        weightG: Int? = nil,
        remainingG: Double? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.roaster = roaster
        self.region = region
        self.farm = farm
        self.producer = producer
        self.altitudeMinM = altitudeMinM
        self.altitudeMaxM = altitudeMaxM
        self.roastDate = roastDate
        self.harvestYear = harvestYear
        self.scaScore = scaScore
        self.weightG = weightG
        self.remainingG = remainingG
        self.notes = notes
    }
}

/// Validation rules for coffee beans. Limits mirror the CHECK constraints of `coffee_beans`.
public enum BeanRules {
    public static let shortTextMaxLength = 120
    public static let notesMaxLength = 2_000
    public static let altitudeRange: ClosedRange<Int> = 0...3_500
    public static let harvestYearRange: ClosedRange<Int> = 1_900...2_100
    public static let scaScoreRange: ClosedRange<Double> = 0...100
    public static let weightRange: ClosedRange<Int> = 1...100_000
    public static let remainingRange: ClosedRange<Double> = 0...100_000

    /// - Parameter today: the current day, used to reject roast dates in the future.
    public static func validate(_ bean: BeanParameters, today: CalendarDate) -> [RuleViolation] {
        var check = ViolationCollector()

        check.requireText(bean.name, field: "name", maxLength: shortTextMaxLength)
        check.optionalText(bean.roaster, field: "roaster", maxLength: shortTextMaxLength)
        check.optionalText(bean.region, field: "region", maxLength: shortTextMaxLength)
        check.optionalText(bean.farm, field: "farm", maxLength: shortTextMaxLength)
        check.optionalText(bean.producer, field: "producer", maxLength: shortTextMaxLength)
        check.optionalText(bean.notes, field: "notes", maxLength: notesMaxLength)

        check.range(bean.altitudeMinM, field: "altitudeMinM", altitudeRange)
        check.range(bean.altitudeMaxM, field: "altitudeMaxM", altitudeRange)
        if let min = bean.altitudeMinM, let max = bean.altitudeMaxM, min > max {
            check.add("altitudeMinM", .exceeds(field: "altitudeMaxM"))
        }
        if let roastDate = bean.roastDate, roastDate > today {
            check.add("roastDate", .inFuture)
        }
        check.range(bean.harvestYear, field: "harvestYear", harvestYearRange)
        check.range(bean.scaScore, field: "scaScore", scaScoreRange)
        check.range(bean.weightG, field: "weightG", weightRange)
        check.range(bean.remainingG, field: "remainingG", remainingRange)

        return check.violations
    }
}
