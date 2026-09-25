import Foundation

/// A calendar day without time or time zone (e.g. a roast date).
/// Encoded as an ISO 8601 date string: `"2026-09-25"`.
public struct CalendarDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = Self.gregorian.date(from: components)
        else { return nil }
        let normalized = Self.gregorian.dateComponents([.year, .month, .day], from: date)
        // Rejects impossible days such as February 30th, which Calendar would roll over.
        guard normalized.year == year, normalized.month == month, normalized.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `"YYYY-MM-DD"`.
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The calendar day of `date` in the given time zone.
    public init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    public static func today(timeZone: TimeZone = .current) -> CalendarDate {
        CalendarDate(date: Date(), timeZone: timeZone)
    }

    public var isoString: String {
        let y = String(year).leftPadded(to: 4)
        let m = String(month).leftPadded(to: 2)
        let d = String(day).leftPadded(to: 2)
        return "\(y)-\(m)-\(d)"
    }

    /// Midnight of this day in the given time zone.
    public func date(in timeZone: TimeZone = .current) -> Date {
        var calendar = Self.gregorian
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    public func days(until other: CalendarDate) -> Int {
        let utc = TimeZone(identifier: "UTC")!
        let seconds = other.date(in: utc).timeIntervalSince(date(in: utc))
        return Int((seconds / 86_400).rounded())
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

extension CalendarDate: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = CalendarDate(isoString: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a date formatted as YYYY-MM-DD, got \"\(string)\"."
            )
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

extension CalendarDate: CustomStringConvertible {
    public var description: String { isoString }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
