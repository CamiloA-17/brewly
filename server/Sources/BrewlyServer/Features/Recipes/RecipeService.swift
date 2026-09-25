import BrewlyAPI
import Foundation
import PostgresNIO

/// Business rules for recipes (preparations).
struct RecipeService: Sendable {
    let recipes: any RecipeRepository
    let catalog: any CatalogRepository

    func list(scope: RecipeListScope, viewerID: UUID, cursor: String?, limit: Int) async throws -> BrewlyAPI.Page<RecipeSummaryDTO> {
        var pageCursor: PageCursor?
        if let cursor {
            guard let decoded = PageCursor(encoded: cursor) else {
                throw AppError(status: .badRequest, code: APIErrorCode.badRequest, message: "Invalid cursor.")
            }
            pageCursor = decoded
        }
        return try await recipes.list(scope: scope, viewerID: viewerID, after: pageCursor, limit: limit)
    }

    func get(id: UUID, viewerID: UUID) async throws -> RecipeDTO {
        guard let recipe = try await recipes.find(id: id, viewerID: viewerID) else { throw AppError.notFound("Recipe") }
        return recipe
    }

    func create(authorID: UUID, _ request: UpsertRecipeRequest) async throws -> RecipeDTO {
        let recipe = try await validated(request)
        return try await mappingReferenceErrors { try await recipes.create(authorID: authorID, recipe) }
    }

    func update(id: UUID, authorID: UUID, _ request: UpsertRecipeRequest) async throws -> RecipeDTO {
        let recipe = try await validated(request)
        let updated = try await mappingReferenceErrors { try await recipes.update(id: id, authorID: authorID, recipe) }
        guard let updated else { throw AppError.notFound("Recipe") }
        return updated
    }

    func delete(id: UUID, authorID: UUID) async throws {
        guard try await recipes.delete(id: id, authorID: authorID) else { throw AppError.notFound("Recipe") }
    }

    /// Checks the recipe against its brew method and normalizes optional text.
    func validated(_ request: UpsertRecipeRequest) async throws -> UpsertRecipeRequest {
        guard let method = try await catalog.brewMethod(slug: request.methodSlug) else {
            throw AppError.unknownReference(field: "methodSlug")
        }
        let violations = RecipeRules.validate(request.parameters, ratioBasis: method.ratioBasis)
        guard violations.isEmpty else { throw AppError.validation(violations) }

        var recipe = request
        recipe.title = request.title.trimmingWhitespace
        recipe.description = request.description.nilIfBlank
        recipe.grinderSlug = request.grinderSlug.nilIfBlank
        recipe.grindSetting = request.grindSetting.nilIfBlank
        recipe.waterProfile = request.waterProfile.nilIfBlank
        recipe.notes = request.notes.nilIfBlank
        recipe.flavorNoteSlugs = request.flavorNoteSlugs.uniqued
        recipe.steps = request.steps.map { step in
            var step = step
            step.instruction = step.instruction.nilIfBlank
            return step
        }
        return recipe
    }

    /// Maps foreign key violations to the request field that references a missing item.
    private func mappingReferenceErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PSQLError where error.isForeignKeyViolation {
            let field = switch error.constraintName {
            case "recipes_bean_owned_by_author": "beanId"
            case "recipes_method_slug_fkey": "methodSlug"
            case "recipes_grinder_slug_fkey": "grinderSlug"
            case "recipe_flavor_notes_flavor_note_slug_fkey": "flavorNoteSlugs"
            default: "unknown"
            }
            throw AppError.unknownReference(field: field)
        }
    }
}
