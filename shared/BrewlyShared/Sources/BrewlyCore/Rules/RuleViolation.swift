/// A single broken validation rule.
///
/// Violations are structured so that each client renders its own localized message:
/// the server uses `defaultMessage` (English), the iOS app localizes `kind`.
public struct RuleViolation: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The value is missing or blank.
        case required
        /// The value must be within `min...max`.
        case outOfRange(min: Double, max: Double)
        /// The text is longer than `max` characters.
        case tooLong(max: Int)
        /// The value does not have the expected format.
        case invalidFormat
        /// The value must not be provided in this context.
        case notAllowed
        /// The value must not exceed the value of another field.
        case exceeds(field: String)
        /// The date must not be in the future.
        case inFuture
        /// A list has more than `max` items.
        case tooMany(max: Int)
        /// The person is younger than `minimumAge` years.
        case tooYoung(minimumAge: Int)
        /// The date must not be earlier than the date of another field.
        case before(field: String)
    }

    /// JSON key of the offending request property, e.g. `"doseG"` or `"steps[2].startS"`.
    public let field: String
    public let kind: Kind

    public init(field: String, kind: Kind) {
        self.field = field
        self.kind = kind
    }

    /// Stable machine-readable code, e.g. `"out_of_range"`.
    public var code: String {
        switch kind {
        case .required: "required"
        case .outOfRange: "out_of_range"
        case .tooLong: "too_long"
        case .invalidFormat: "invalid_format"
        case .notAllowed: "not_allowed"
        case .exceeds: "exceeds"
        case .inFuture: "in_future"
        case .tooMany: "too_many"
        case .tooYoung: "too_young"
        case .before: "before"
        }
    }

    /// English message used by the server and as a fallback.
    public var defaultMessage: String {
        switch kind {
        case .required:
            "This field is required."
        case let .outOfRange(min, max):
            "Must be between \(Self.format(min)) and \(Self.format(max))."
        case let .tooLong(max):
            "Must be at most \(max) characters."
        case .invalidFormat:
            "Has an invalid format."
        case .notAllowed:
            "Is not allowed here."
        case let .exceeds(field):
            "Must not exceed \(field)."
        case .inFuture:
            "Must not be in the future."
        case let .tooMany(max):
            "Must have at most \(max) items."
        case let .tooYoung(minimumAge):
            "You must be at least \(minimumAge) years old."
        case let .before(field):
            "Must not be before \(field)."
        }
    }

    /// Formats a bound without a trailing `.0` for whole numbers.
    public static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}

/// Collects violations while checking a value.
struct ViolationCollector {
    private(set) var violations: [RuleViolation] = []

    mutating func add(_ field: String, _ kind: RuleViolation.Kind) {
        violations.append(RuleViolation(field: field, kind: kind))
    }

    mutating func requireText(_ value: String, field: String, maxLength: Int) {
        let trimmed = value.trimmingWhitespace
        if trimmed.isEmpty {
            add(field, .required)
        } else if trimmed.count > maxLength {
            add(field, .tooLong(max: maxLength))
        }
    }

    mutating func optionalText(_ value: String?, field: String, maxLength: Int) {
        guard let value, value.trimmingWhitespace.count > maxLength else { return }
        add(field, .tooLong(max: maxLength))
    }

    mutating func range<T: BinaryFloatingPoint>(_ value: T?, field: String, _ range: ClosedRange<T>) {
        guard let value, !range.contains(value) else { return }
        add(field, .outOfRange(min: Double(range.lowerBound), max: Double(range.upperBound)))
    }

    mutating func range(_ value: Int?, field: String, _ range: ClosedRange<Int>) {
        guard let value, !range.contains(value) else { return }
        add(field, .outOfRange(min: Double(range.lowerBound), max: Double(range.upperBound)))
    }
}

extension String {
    /// The string without leading and trailing whitespace and newlines.
    public var trimmingWhitespace: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
