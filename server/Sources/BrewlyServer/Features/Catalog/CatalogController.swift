import Vapor

/// `GET /v1/catalog`: every global catalog in one response, cacheable by the app.
struct CatalogController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("catalog", use: catalog)
    }

    @Sendable
    func catalog(req: Request) async throws -> Response {
        let catalog = try await PostgresCatalogRepository(database: req.db).catalog()
        let response = try Response.json(catalog)
        response.headers.replaceOrAdd(name: .cacheControl, value: "private, max-age=3600")
        return response
    }
}
