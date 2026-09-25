import Fluent
import SQLKit
import Vapor

/// `GET /health`: liveness plus a database round trip.
struct HealthController: RouteCollection {
    struct HealthResponse: Content {
        var status: String
        var database: String
    }

    func boot(routes: any RoutesBuilder) throws {
        routes.get("health", use: health)
    }

    @Sendable
    func health(req: Request) async throws -> Response {
        do {
            _ = try await req.db.sql.raw("SELECT 1").first()
            return try .json(HealthResponse(status: "ok", database: "ok"))
        } catch {
            req.logger.error("Health check failed: \(String(describing: error))")
            return try .json(HealthResponse(status: "degraded", database: "unreachable"), status: .serviceUnavailable)
        }
    }
}
