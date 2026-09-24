import BrewlyDomain
import Foundation
import Supabase

/// Punto de entrada de la capa de datos: crea el cliente de Supabase y todos
/// los repositorios que lo usan.
public enum SupabaseEnvironment {
    public static func makeDependencies(url: URL, anonKey: String) -> AppDependencies {
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                db: .init(encoder: .brewly, decoder: .brewly)
            )
        )
        return AppDependencies(
            auth: SupabaseAuthRepository(client: client),
            profiles: SupabaseProfileRepository(client: client),
            coffee: SupabaseCoffeeRepository(client: client),
            recipes: SupabaseRecipeRepository(client: client),
            brews: SupabaseBrewRepository(client: client),
            social: SupabaseSocialRepository(client: client),
            relationships: SupabaseRelationshipRepository(client: client),
            notifications: SupabaseNotificationRepository(client: client)
        )
    }
}

// MARK: - Codificación JSON compatible con PostgREST

extension JSONDecoder {
    /// PostgREST devuelve fechas como `2026-09-24T10:00:00.123456+00:00`
    /// (timestamptz) o `2026-09-24` (date).
    static let brewly: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = PostgresDate.parse(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Fecha no reconocida: \(raw)"
            )
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let brewly: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(PostgresDate.format(date))
        }
        return encoder
    }()
}

enum PostgresDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ raw: String) -> Date? {
        // ISO8601DateFormatter solo acepta hasta milisegundos: se recortan los
        // microsegundos que envía PostgreSQL.
        let normalized = raw.replacingOccurrences(
            of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression
        )
        return withFraction.date(from: normalized)
            ?? withoutFraction.date(from: normalized)
            ?? dateOnly.date(from: raw)
    }

    static func format(_ date: Date) -> String {
        withFraction.string(from: date)
    }
}

// MARK: - Utilidades comunes

extension SupabaseClient {
    func requireUserID() throws -> UUID {
        guard let id = auth.currentUser?.id else { throw BrewlyError.notAuthenticated }
        return id
    }
}

/// Fragmentos de `select` reutilizados por varios repositorios.
enum Select {
    static let recipe = "*, method:brew_methods(*), bean:coffee_beans(*), steps:recipe_steps(*)"
    static let post = """
    *, liked_by_me, saved_by_me, \
    author:profiles(*), \
    media:post_media(*), \
    recipe:recipes(*, method:brew_methods(*), steps:recipe_steps(*)), \
    brew:brews(*), \
    bean:coffee_beans(*)
    """
    static let comment = "*, author:profiles(*)"
    static let notification = "*, actor:profiles!notifications_actor_id_fkey(*)"
}
