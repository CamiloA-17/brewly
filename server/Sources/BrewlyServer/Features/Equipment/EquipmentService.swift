import BrewlyAPI
import Foundation
import PostgresNIO

/// Business rules for members' gear.
struct EquipmentService: Sendable {
    let equipment: any EquipmentRepository

    func mine(ownerID: UUID) async throws -> [EquipmentDTO] {
        try await equipment.list(ownerID: ownerID)
    }

    /// Another member's gear, public like their profile (hidden when a block exists).
    func ofMember(_ ownerID: UUID, viewerID: UUID) async throws -> [EquipmentDTO] {
        guard try await equipment.canViewProfile(ownerID: ownerID, viewerID: viewerID) else {
            throw AppError.notFound("User")
        }
        return try await equipment.list(ownerID: ownerID)
    }

    func create(ownerID: UUID, _ request: UpsertEquipmentRequest) async throws -> EquipmentDTO {
        let item = try validated(request)
        return try await mappingReferenceErrors { try await equipment.create(ownerID: ownerID, item) }
    }

    func update(id: UUID, ownerID: UUID, _ request: UpsertEquipmentRequest) async throws -> EquipmentDTO {
        let item = try validated(request)
        let updated = try await mappingReferenceErrors { try await equipment.update(id: id, ownerID: ownerID, item) }
        guard let updated else { throw AppError.notFound("Equipment") }
        return updated
    }

    func delete(id: UUID, ownerID: UUID) async throws {
        guard try await equipment.delete(id: id, ownerID: ownerID) else { throw AppError.notFound("Equipment") }
    }

    /// Validates the request, turns blank text into `nil` and keeps the last setting of each method.
    func validated(_ request: UpsertEquipmentRequest) throws -> UpsertEquipmentRequest {
        let violations = request.violations
        guard violations.isEmpty else { throw AppError.validation(violations) }

        var item = request
        item.grinderSlug = request.grinderSlug.nilIfBlank
        item.brand = request.brand.nilIfBlank
        item.model = request.model.nilIfBlank
        item.nickname = request.nickname.nilIfBlank
        item.notes = request.notes.nilIfBlank
        var settings: [String: String] = [:]
        for setting in request.grindSettings {
            settings[setting.methodSlug.trimmingWhitespace] = setting.grindSetting.trimmingWhitespace
        }
        item.grindSettings = settings
            .map { GrindSettingInput(methodSlug: $0.key, grindSetting: $0.value) }
            .sorted { $0.methodSlug < $1.methodSlug }
        return item
    }

    /// Unknown catalog references surface as foreign key violations; report the offending field.
    private func mappingReferenceErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PSQLError where error.isForeignKeyViolation {
            let field = error.constraintName == "user_equipment_grinder_slug_fkey" ? "grinderSlug" : "grindSettings"
            throw AppError.unknownReference(field: field)
        }
    }
}
