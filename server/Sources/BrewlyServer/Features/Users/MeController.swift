import BrewlyAPI
import Vapor

/// The signed-in user's profile, account and brew methods.
struct MeController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let me = routes.grouped("me")
        me.get(use: profile)
        me.patch(use: updateProfile)
        me.put("onboarding", use: completeOnboarding)
        me.delete(use: deleteAccount)
        me.get("methods", use: methods)
        me.put("methods", ":slug", use: addMethod)
        me.delete("methods", ":slug", use: removeMethod)
    }

    @Sendable
    func profile(req: Request) async throws -> Response {
        guard let user = try await repository(req).find(id: try req.userID) else { throw AppError.unauthorized }
        return try .json(user)
    }

    @Sendable
    func updateProfile(req: Request) async throws -> Response {
        let body = try req.decodeJSON(UpdateProfileRequest.self)
        let countryCode = body.countryCode.nilIfBlank?.uppercased()
        let violations = AccountRules.validateProfile(
            displayName: body.displayName, firstName: body.firstName, lastName: body.lastName,
            birthDate: body.birthDate, bio: body.bio, countryCode: countryCode, city: body.city
        )
        guard violations.isEmpty, let birthDate = body.birthDate else { throw AppError.validation(violations) }

        let updated = try await repository(req).updateProfile(id: try req.userID, ProfileUpdate(
            displayName: body.displayName.trimmingWhitespace,
            firstName: body.firstName.trimmingWhitespace,
            lastName: body.lastName.trimmingWhitespace,
            birthDate: birthDate,
            bio: body.bio.nilIfBlank,
            countryCode: countryCode,
            city: body.city.nilIfBlank
        ))
        guard let updated else { throw AppError.unauthorized }
        return try .json(updated)
    }

    /// Private details of accounts that do not have them yet (created before they were required,
    /// or with Sign in with Apple). Also usable to correct them later.
    @Sendable
    func completeOnboarding(req: Request) async throws -> Response {
        let body = try req.decodeJSON(CompleteOnboardingRequest.self)
        let violations = AccountRules.validateOnboarding(
            firstName: body.firstName, lastName: body.lastName, birthDate: body.birthDate,
            acceptedTerms: body.acceptedTerms
        )
        guard violations.isEmpty, let birthDate = body.birthDate else { throw AppError.validation(violations) }

        let updated = try await repository(req).completeOnboarding(
            id: try req.userID,
            firstName: body.firstName.trimmingWhitespace,
            lastName: body.lastName.trimmingWhitespace,
            birthDate: birthDate
        )
        guard let updated else { throw AppError.unauthorized }
        return try .json(updated)
    }

    /// Deletes the account and everything it owns (App Store Review Guideline 5.1.1(v)).
    @Sendable
    func deleteAccount(req: Request) async throws -> HTTPStatus {
        try await repository(req).delete(id: try req.userID)
        return .noContent
    }

    @Sendable
    func methods(req: Request) async throws -> Response {
        let slugs = try await repository(req).methodSlugs(userID: try req.userID)
        return try .json(UserMethodsDTO(methodSlugs: slugs))
    }

    @Sendable
    func addMethod(req: Request) async throws -> HTTPStatus {
        let slug = req.parameters.get("slug") ?? ""
        guard try await repository(req).addMethod(userID: try req.userID, slug: slug) else {
            throw AppError.notFound("Brew method")
        }
        return .noContent
    }

    @Sendable
    func removeMethod(req: Request) async throws -> HTTPStatus {
        let slug = req.parameters.get("slug") ?? ""
        try await repository(req).removeMethod(userID: try req.userID, slug: slug)
        return .noContent
    }

    private func repository(_ req: Request) -> any UserRepository {
        PostgresUserRepository(database: req.db)
    }
}
