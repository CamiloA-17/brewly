import JWT
import Vapor

/// Claims of the short-lived access token.
struct AccessTokenPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}

/// The user making the request, set by `AccessTokenAuthenticator`.
struct AuthenticatedUser: Authenticatable {
    let id: UUID
}

/// Reads `Authorization: Bearer <access token>` and logs the user in when the token is valid.
struct AccessTokenAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard let payload = try? await request.jwt.verify(bearer.token, as: AccessTokenPayload.self),
              let userID = UUID(uuidString: payload.subject.value)
        else { return }
        request.auth.login(AuthenticatedUser(id: userID))
    }
}

extension Request {
    /// The authenticated user's id. Only valid behind `AuthenticatedUser.guardMiddleware()`.
    var userID: UUID {
        get throws {
            guard let user = auth.get(AuthenticatedUser.self) else { throw AppError.unauthorized }
            return user.id
        }
    }
}
