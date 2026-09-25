import Foundation

/// Opaque keyset-pagination cursor over `(created_at, id)`, both in descending order.
struct PageCursor: Codable, Equatable, Sendable {
    /// `created_at` rendered by PostgreSQL with microsecond precision (UTC).
    var createdAt: String
    var id: UUID

    /// SQL expression producing `createdAt` for a `timestamptz` column.
    static func sqlTimestamp(_ column: String) -> String {
        "to_char(\(column) AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"')"
    }

    func encoded() -> String {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes a cursor produced by `encoded()`; `nil` for malformed input.
    init?(encoded: String) {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let cursor = try? JSONDecoder().decode(PageCursor.self, from: data)
        else { return nil }
        self = cursor
    }

    init(createdAt: String, id: UUID) {
        self.createdAt = createdAt
        self.id = id
    }
}
