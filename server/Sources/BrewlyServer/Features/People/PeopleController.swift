import BrewlyAPI
import Vapor

/// Other members: search, public profiles, their recipes and the follow graph.
struct PeopleController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.get(use: search)
        users.get(":userID", use: profile)
        users.get(":userID", "recipes", use: recipes)
        users.get(":userID", "followers", use: followers)
        users.get(":userID", "following", use: following)
        users.put(":userID", "follow", use: follow)
        users.delete(":userID", "follow", use: unfollow)
    }

    /// `GET /users?q=`: members whose username or name starts with `q` (at most 20).
    @Sendable
    func search(req: Request) async throws -> Response {
        try .json(try await service(req).search(query: req.query[String.self, at: "q"], viewerID: try req.userID))
    }

    @Sendable
    func profile(req: Request) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        return try .json(try await service(req).profile(id: id, viewerID: try req.userID))
    }

    /// `GET /users/{id}/recipes?cursor=&limit=`: the member's recipes the viewer can see.
    @Sendable
    func recipes(req: Request) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        let viewerID = try req.userID
        _ = try await service(req).profile(id: id, viewerID: viewerID)
        let recipes = RecipeService(
            recipes: PostgresRecipeRepository(database: req.db), catalog: PostgresCatalogRepository(database: req.db)
        )
        let page = try await recipes.list(
            scope: .visibleFrom(authorID: id), viewerID: viewerID,
            cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func followers(req: Request) async throws -> Response {
        try await followList(req, kind: .followers)
    }

    @Sendable
    func following(req: Request) async throws -> Response {
        try await followList(req, kind: .following)
    }

    /// `PUT /users/{id}/follow`: idempotent.
    @Sendable
    func follow(req: Request) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        return try .json(try await service(req).follow(memberID: id, followerID: try req.userID))
    }

    /// `DELETE /users/{id}/follow`: idempotent.
    @Sendable
    func unfollow(req: Request) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        return try .json(try await service(req).unfollow(memberID: id, followerID: try req.userID))
    }

    private func followList(_ req: Request, kind: FollowListKind) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        let page = try await service(req).follows(
            of: id, kind: kind, viewerID: try req.userID,
            cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    private func service(_ req: Request) -> PeopleService {
        PeopleService(people: PostgresPeopleRepository(database: req.db))
    }
}
