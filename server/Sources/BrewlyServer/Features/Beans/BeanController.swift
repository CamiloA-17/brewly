import BrewlyAPI
import Vapor

struct BeanController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("me", "beans", use: myBeans)
        let beans = routes.grouped("beans")
        beans.post(use: create)
        beans.get(":beanID", use: show)
        beans.put(":beanID", use: update)
        beans.delete(":beanID", use: delete)
    }

    @Sendable
    func myBeans(req: Request) async throws -> Response {
        let includeArchived = req.query[Bool.self, at: "includeArchived"] ?? false
        return try .json(try await service(req).list(ownerID: try req.userID, includeArchived: includeArchived))
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let bean = try await service(req).create(ownerID: try req.userID, try req.decodeJSON(UpsertBeanRequest.self))
        return try .json(bean, status: .created)
    }

    @Sendable
    func show(req: Request) async throws -> Response {
        let id = try req.uuidParameter("beanID", resource: "Bean")
        return try .json(try await service(req).get(id: id, viewerID: try req.userID))
    }

    @Sendable
    func update(req: Request) async throws -> Response {
        let id = try req.uuidParameter("beanID", resource: "Bean")
        let body = try req.decodeJSON(UpsertBeanRequest.self)
        return try .json(try await service(req).update(id: id, ownerID: try req.userID, body))
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("beanID", resource: "Bean")
        try await service(req).delete(id: id, ownerID: try req.userID)
        return .noContent
    }

    private func service(_ req: Request) -> BeanService {
        BeanService(beans: PostgresBeanRepository(database: req.db))
    }
}
