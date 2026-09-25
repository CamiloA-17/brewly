import Fluent
import FluentPostgresDriver
import JWT
import Vapor

/// Configures services, middleware and routes.
func configure(_ app: Application) async throws {
    let config = try AppConfig.load(from: app.environment)
    app.appConfig = config

    app.databases.use(
        .postgres(configuration: try SQLPostgresConfiguration(url: config.databaseURL)),
        as: .psql
    )

    await app.jwt.keys.add(hmac: HMACKey(from: config.jwtSecret), digestAlgorithm: .sha256)

    // Replace the default error middleware so every error uses the API error format.
    app.middleware = .init()
    app.middleware.use(RouteLoggingMiddleware(logLevel: .info))
    app.middleware.use(APIErrorMiddleware(environment: app.environment))

    try routes(app)
}
