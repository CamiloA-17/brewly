import BrewlyAPI
import Foundation
import PostgresNIO

/// Email/password authentication with short-lived access tokens and rotating refresh tokens.
struct AuthService: Sendable {
    let auth: any AuthRepository
    let users: any UserRepository
    let passwords: any PasswordHashing
    let tokens: TokenService

    func register(_ body: RegisterRequest) async throws -> AuthResponse {
        let violations = AccountRules.validateSignUp(
            email: body.email, password: body.password, username: body.username, displayName: body.displayName,
            firstName: body.firstName, lastName: body.lastName, birthDate: body.birthDate,
            acceptedTerms: body.acceptedTerms
        )
        guard violations.isEmpty, let birthDate = body.birthDate else { throw AppError.validation(violations) }

        let firstName = body.firstName.trimmingWhitespace
        let lastName = body.lastName.trimmingWhitespace
        let passwordHash = try await passwords.hash(body.password)
        let userID: UUID
        do {
            userID = try await auth.createPasswordUser(NewPasswordUser(
                email: AccountRules.normalize(body.email),
                username: AccountRules.normalize(body.username),
                displayName: body.displayName.nilIfBlank
                    ?? AccountRules.defaultDisplayName(firstName: firstName, lastName: lastName),
                firstName: firstName,
                lastName: lastName,
                birthDate: birthDate,
                passwordHash: passwordHash
            ))
        } catch let error as PSQLError where error.isUniqueViolation {
            if error.constraintName == "users_username_key" {
                throw AppError.conflict(code: APIErrorCode.usernameTaken, message: "That username is already taken.")
            }
            throw AppError.conflict(code: APIErrorCode.emailTaken, message: "An account with that email already exists.")
        }
        return try await issueTokens(for: userID)
    }

    func login(_ body: LoginRequest) async throws -> AuthResponse {
        guard let credentials = try await auth.passwordCredentials(email: AccountRules.normalize(body.email)),
              try await passwords.verify(body.password, against: credentials.passwordHash)
        else { throw AppError.invalidCredentials }
        return try await issueTokens(for: credentials.userID)
    }

    /// Exchanges a refresh token for a new token pair. Reusing a consumed token revokes
    /// every session of the user, since it means the token was stolen.
    func refresh(_ body: RefreshTokenRequest) async throws -> AuthResponse {
        switch try await auth.consumeRefreshToken(tokenHash: TokenService.hash(refreshToken: body.refreshToken)) {
        case let .valid(userID):
            return try await issueTokens(for: userID)
        case let .reused(userID):
            try await auth.revokeAllRefreshTokens(userID: userID)
            throw AppError.unauthorized
        case .invalid:
            throw AppError.unauthorized
        }
    }

    func logout(_ body: RefreshTokenRequest) async throws {
        try await auth.revokeRefreshToken(tokenHash: TokenService.hash(refreshToken: body.refreshToken))
    }

    private func issueTokens(for userID: UUID) async throws -> AuthResponse {
        guard let user = try await users.find(id: userID) else { throw AppError.unauthorized }
        let now = Date()
        let access = try await tokens.makeAccessToken(userID: userID, now: now)
        let refreshToken = TokenService.makeRefreshToken()
        let refreshExpiresAt = tokens.refreshTokenExpiry(now: now)
        try await auth.storeRefreshToken(
            userID: userID,
            tokenHash: TokenService.hash(refreshToken: refreshToken),
            expiresAt: refreshExpiresAt
        )
        return AuthResponse(
            accessToken: access.token,
            accessTokenExpiresAt: access.expiresAt,
            refreshToken: refreshToken,
            refreshTokenExpiresAt: refreshExpiresAt,
            user: user
        )
    }
}
