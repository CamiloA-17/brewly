import BrewlyAPI
import Vapor

struct RecipeController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("me", "recipes", use: myRecipes)
        routes.get("me", "saved-recipes", use: savedRecipes)
        let recipes = routes.grouped("recipes")
        recipes.get(use: explore)
        recipes.post(use: create)
        recipes.get(":recipeID", use: show)
        recipes.put(":recipeID", use: update)
        recipes.delete(":recipeID", use: delete)
        recipes.put(":recipeID", "save", use: save)
        recipes.delete(":recipeID", "save", use: unsave)
    }

    /// `GET /me/recipes?cursor=&limit=`
    @Sendable
    func myRecipes(req: Request) async throws -> Response {
        let userID = try req.userID
        let page = try await service(req).list(
            scope: .authoredBy(userID), viewerID: userID, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    /// `GET /me/saved-recipes?cursor=&limit=`: newest save first.
    @Sendable
    func savedRecipes(req: Request) async throws -> Response {
        let page = try await service(req).list(
            scope: .savedByViewer, viewerID: try req.userID, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    /// `GET /recipes?method=&country=&varietal=&cursor=&limit=`: public recipes of the community.
    @Sendable
    func explore(req: Request) async throws -> Response {
        let scope = RecipeListScope.explore(
            methodSlug: req.query[String.self, at: "method"],
            countryCode: req.query[String.self, at: "country"]?.uppercased(),
            varietalSlug: req.query[String.self, at: "varietal"]
        )
        let page = try await service(req).list(
            scope: scope, viewerID: try req.userID, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let recipe = try await service(req).create(authorID: try req.userID, try req.decodeJSON(UpsertRecipeRequest.self))
        return try .json(recipe, status: .created)
    }

    @Sendable
    func show(req: Request) async throws -> Response {
        let id = try req.uuidParameter("recipeID", resource: "Recipe")
        return try .json(try await service(req).get(id: id, viewerID: try req.userID))
    }

    @Sendable
    func update(req: Request) async throws -> Response {
        let id = try req.uuidParameter("recipeID", resource: "Recipe")
        let body = try req.decodeJSON(UpsertRecipeRequest.self)
        return try .json(try await service(req).update(id: id, authorID: try req.userID, body))
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("recipeID", resource: "Recipe")
        try await service(req).delete(id: id, authorID: try req.userID)
        return .noContent
    }

    /// `PUT /recipes/{id}/save`: idempotent.
    @Sendable
    func save(req: Request) async throws -> Response {
        let id = try req.uuidParameter("recipeID", resource: "Recipe")
        return try .json(try await service(req).save(id: id, userID: try req.userID))
    }

    /// `DELETE /recipes/{id}/save`: idempotent.
    @Sendable
    func unsave(req: Request) async throws -> Response {
        let id = try req.uuidParameter("recipeID", resource: "Recipe")
        return try .json(try await service(req).unsave(id: id, userID: try req.userID))
    }

    private func service(_ req: Request) -> RecipeService {
        RecipeService(
            recipes: PostgresRecipeRepository(database: req.db),
            catalog: PostgresCatalogRepository(database: req.db)
        )
    }
}
