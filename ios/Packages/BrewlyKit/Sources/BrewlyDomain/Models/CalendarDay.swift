import Foundation

/// Fecha sin hora (columnas `date` de PostgreSQL), serializada como `yyyy-MM-dd`
/// en la zona horaria local.
public struct CalendarDay: Codable, Hashable, Sendable {
    public let date: Date

    public init(_ date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = Self.formatter().date(from: String(raw.prefix(10))) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Día inválido: \(raw)"
            )
        }
        self.date = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.formatter().string(from: date))
    }

    private static func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
