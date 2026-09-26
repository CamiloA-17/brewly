import BrewlyAPI
import Foundation
import PostgresNIO

/// Business rules for the brew journal.
struct BrewLogService: Sendable {
    let brews: any BrewLogRepository
    let recipes: any RecipeRepository
    let catalog: any CatalogRepository

    func list(userID: UUID, filter: BrewLogFilter, cursor: String?, limit: Int) async throws -> BrewlyAPI.Page<BrewLogDTO> {
        try await brews.list(userID: userID, filter: filter, after: try PageCursor.decodeParameter(cursor), limit: limit)
    }

    func get(id: UUID, viewerID: UUID) async throws -> BrewLogDTO {
        guard let brew = try await brews.find(id: id, viewerID: viewerID) else { throw AppError.notFound("Brew") }
        return brew
    }

    func create(userID: UUID, _ request: UpsertBrewLogRequest) async throws -> BrewLogDTO {
        let brew = try await validated(request, userID: userID)
        return try await mappingReferenceErrors { try await brews.create(userID: userID, brew) }
    }

    func update(id: UUID, userID: UUID, _ request: UpsertBrewLogRequest) async throws -> BrewLogDTO {
        let brew = try await validated(request, userID: userID)
        let updated = try await mappingReferenceErrors { try await brews.update(id: id, userID: userID, brew) }
        guard let updated else { throw AppError.notFound("Brew") }
        return updated
    }

    func delete(id: UUID, userID: UUID) async throws {
        guard try await brews.delete(id: id, userID: userID) else { throw AppError.notFound("Brew") }
    }

    /// Checks the brew against its method and the followed recipe, and normalizes optional text.
    func validated(_ request: UpsertBrewLogRequest, userID: UUID, now: Date = Date()) async throws -> UpsertBrewLogRequest {
        guard let method = try await catalog.brewMethod(slug: request.methodSlug) else {
            throw AppError.unknownReference(field: "methodSlug")
        }
        let violations = BrewRules.validate(request.parameters, ratioBasis: method.ratioBasis, now: now)
        guard violations.isEmpty else { throw AppError.validation(violations) }
        // A brew can follow any recipe the member can see, including other members' ones.
        if let recipeID = request.recipeId, try await recipes.find(id: recipeID, viewerID: userID) == nil {
            throw AppError.unknownReference(field: "recipeId")
        }

        var brew = request
        brew.grindSetting = request.grindSetting.nilIfBlank
        brew.notes = request.notes.nilIfBlank
        brew.flavorNoteSlugs = request.flavorNoteSlugs.uniqued
        return brew
    }

    /// Maps foreign key violations and unusable photos to the request field at fault.
    private func mappingReferenceErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch is UnavailableBrewPhotoError {
            throw AppError.unknownReference(field: "photoMediaId")
        } catch let error as PSQLError where error.isForeignKeyViolation {
            let field = switch error.constraintName {
            case "brew_logs_bean_owned_by_user": "beanId"
            case "brew_logs_equipment_owned_by_user": "equipmentId"
            case "brew_logs_recipe_id_fkey": "recipeId"
            case "brew_logs_method_slug_fkey": "methodSlug"
            case "brew_log_flavor_notes_flavor_note_slug_fkey": "flavorNoteSlugs"
            default: "unknown"
            }
            throw AppError.unknownReference(field: field)
        }
    }
}
