import BrewlyAPI
import Vapor

struct BrewSessionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let brews = routes.grouped("me", "brew-sessions")
        brews.get(use: list)
        brews.post(use: create)
    }

    @Sendable
    func list(req: Request) async throws -> Response {
        let recipeID: UUID?
        if let raw = req.query[String.self, at: "recipeId"] {
            guard let id = UUID(uuidString: raw) else { throw AppError.notFound("Recipe") }
            recipeID = id
        } else {
            recipeID = nil
        }
        let page = try await service(req).list(
            userID: try req.userID, recipeID: recipeID,
            cursor: req.query[String.self, at: "cursor"],
            limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let result = try await service(req).create(
            userID: try req.userID, request: try req.decodeJSON(CreateBrewSessionRequest.self)
        )
        return try .json(result, status: .created)
    }

    private func service(_ req: Request) -> BrewSessionService {
        BrewSessionService(repository: PostgresBrewSessionRepository(database: req.db))
    }
}
