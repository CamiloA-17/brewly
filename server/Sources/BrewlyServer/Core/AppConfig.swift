import Vapor

/// Runtime configuration read from environment variables.
struct AppConfig: Sendable {
    var databaseURL: String
    var jwtSecret: String
    var accessTokenTTL: TimeInterval
    var refreshTokenTTL: TimeInterval

    static func load(from environment: Environment) throws -> AppConfig {
        guard let databaseURL = Environment.get("DATABASE_URL"), !databaseURL.isEmpty else {
            throw ConfigurationError("DATABASE_URL is not set.")
        }
        guard let jwtSecret = Environment.get("JWT_SECRET"), jwtSecret.count >= 32 else {
            throw ConfigurationError("JWT_SECRET must be set and at least 32 characters long.")
        }
        return AppConfig(
            databaseURL: databaseURL,
            jwtSecret: jwtSecret,
            accessTokenTTL: Environment.get("ACCESS_TOKEN_TTL_SECONDS").flatMap(TimeInterval.init) ?? 15 * 60,
            refreshTokenTTL: Environment.get("REFRESH_TOKEN_TTL_SECONDS").flatMap(TimeInterval.init) ?? 30 * 24 * 60 * 60
        )
    }
}

struct ConfigurationError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

extension Application {
    private struct AppConfigKey: StorageKey {
        typealias Value = AppConfig
    }

    var appConfig: AppConfig {
        get {
            guard let config = storage[AppConfigKey.self] else {
                fatalError("AppConfig is not set. Call configure(_:) first.")
            }
            return config
        }
        set { storage[AppConfigKey.self] = newValue }
    }
}
