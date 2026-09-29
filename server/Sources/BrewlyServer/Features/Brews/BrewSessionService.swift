import BrewlyAPI
import Vapor

struct BrewSessionService {
    let repository: any BrewSessionRepository

    func list(userID: UUID, recipeID: UUID?, cursor: String?, limit: Int) async throws -> BrewlyAPI.Page<BrewSessionDTO> {
        try await repository.list(userID: userID, recipeID: recipeID,
                                  after: try PageCursor.decodeParameter(cursor), limit: limit)
    }

    func create(userID: UUID, request: CreateBrewSessionRequest) async throws -> BrewSessionDTO {
        let violations = BrewSessionRules.validate(request.parameters)
        guard violations.isEmpty else { throw AppError.validation(violations) }
        var normalized = request
        normalized.grindSetting = request.grindSetting.nilIfBlank
        normalized.notes = request.notes.nilIfBlank
        guard let result = try await repository.create(userID: userID, request: normalized) else {
            throw AppError.notFound("Recipe")
        }
        return result
    }
}
