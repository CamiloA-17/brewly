import BrewlyAPI
import Vapor

/// Members' gear: the signed-in user's own and other members' (public on their profile).
struct EquipmentController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let mine = routes.grouped("me", "equipment")
        mine.get(use: myEquipment)
        mine.post(use: create)
        mine.put(":equipmentID", use: update)
        mine.delete(":equipmentID", use: delete)
        routes.get("users", ":userID", "equipment", use: memberEquipment)
    }

    @Sendable
    func myEquipment(req: Request) async throws -> Response {
        try .json(try await service(req).mine(ownerID: try req.userID))
    }

    @Sendable
    func memberEquipment(req: Request) async throws -> Response {
        let id = try req.uuidParameter("userID", resource: "User")
        return try .json(try await service(req).ofMember(id, viewerID: try req.userID))
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let item = try await service(req).create(ownerID: try req.userID, try req.decodeJSON(UpsertEquipmentRequest.self))
        return try .json(item, status: .created)
    }

    @Sendable
    func update(req: Request) async throws -> Response {
        let id = try req.uuidParameter("equipmentID", resource: "Equipment")
        let body = try req.decodeJSON(UpsertEquipmentRequest.self)
        return try .json(try await service(req).update(id: id, ownerID: try req.userID, body))
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("equipmentID", resource: "Equipment")
        try await service(req).delete(id: id, ownerID: try req.userID)
        return .noContent
    }

    private func service(_ req: Request) -> EquipmentService {
        EquipmentService(equipment: PostgresEquipmentRepository(database: req.db))
    }
}
