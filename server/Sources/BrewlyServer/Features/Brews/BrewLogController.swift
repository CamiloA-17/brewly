import BrewlyAPI
import Vapor

/// The brew journal: the signed-in member's brews, and brews shared with the viewer.
struct BrewLogController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let mine = routes.grouped("me", "brews")
        mine.get(use: myBrews)
        mine.post(use: create)
        let brews = routes.grouped("brews")
        brews.get(":brewID", use: show)
        brews.put(":brewID", use: update)
        brews.delete(":brewID", use: delete)
    }

    /// `GET /me/brews?beanId=&methodSlug=&cursor=&limit=`: most recent brew first.
    @Sendable
    func myBrews(req: Request) async throws -> Response {
        let filter = BrewLogFilter(
            beanID: req.query[String.self, at: "beanId"].flatMap(UUID.init(uuidString:)),
            methodSlug: req.query[String.self, at: "methodSlug"].nilIfBlank
        )
        let page = try await service(req).list(
            userID: try req.userID, filter: filter, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let brew = try await service(req).create(userID: try req.userID, try req.decodeJSON(UpsertBrewLogRequest.self))
        return try .json(brew, status: .created)
    }

    @Sendable
    func show(req: Request) async throws -> Response {
        let id = try req.uuidParameter("brewID", resource: "Brew")
        return try .json(try await service(req).get(id: id, viewerID: try req.userID))
    }

    @Sendable
    func update(req: Request) async throws -> Response {
        let id = try req.uuidParameter("brewID", resource: "Brew")
        let body = try req.decodeJSON(UpsertBrewLogRequest.self)
        return try .json(try await service(req).update(id: id, userID: try req.userID, body))
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("brewID", resource: "Brew")
        try await service(req).delete(id: id, userID: try req.userID)
        return .noContent
    }

    private func service(_ req: Request) -> BrewLogService {
        BrewLogService(
            brews: PostgresBrewLogRepository(database: req.db),
            recipes: PostgresRecipeRepository(database: req.db),
            catalog: PostgresCatalogRepository(database: req.db)
        )
    }
}
