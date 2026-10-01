import BrewlyAPI
import Foundation
import PostgresNIO

protocol IdentityTokenVerifying: Sendable {
    func requireConfiguration(provider: IdentityProvider) throws
    func verify(_ token: String, provider: IdentityProvider) async throws -> VerifiedIdentity
    func exchangeAppleCode(_ code: String, identity: VerifiedIdentity) async throws -> String
}

struct FederatedAuthService: Sendable {
    let repository: any FederatedAuthRepository
    let verifier: any IdentityTokenVerifying
    let auth: AuthService

    func challenge(_ body: AuthChallengeRequest) async throws -> AuthChallengeResponse {
        try verifier.requireConfiguration(provider: body.provider)
        let nonce = TokenService.makeRefreshToken()
        let expiresAt = Date().addingTimeInterval(5 * 60)
        let id = try await repository.createChallenge(
            provider: body.provider, nonceHash: TokenService.hash(refreshToken: nonce), expiresAt: expiresAt)
        return AuthChallengeResponse(id: id, nonce: nonce, expiresAt: expiresAt)
    }

    func signIn(_ body: FederatedSignInRequest, provider: IdentityProvider) async throws -> AuthResponse {
        guard !body.identityToken.isEmpty, body.identityToken.utf8.count <= 16384 else {
            throw AppError.invalidCredentials
        }
        var identity = try await verifier.verify(body.identityToken, provider: provider)
        guard !identity.subject.isEmpty, !identity.nonce.isEmpty,
            try await repository.consumeChallenge(
                id: body.challengeId, provider: provider,
                nonceHash: TokenService.hash(refreshToken: identity.nonce))
        else {
            throw AppError.invalidCredentials
        }
        if provider == .apple {
            guard let code = body.authorizationCode, !code.isEmpty, code.utf8.count <= 4096 else {
                throw AppError.invalidCredentials
            }
            identity.encryptedRefreshToken = try await verifier.exchangeAppleCode(code, identity: identity)
            identity.firstName = body.firstName
            identity.lastName = body.lastName
        }
        let userID: UUID
        do {
            userID = try await repository.resolveUser(identity)
        } catch let error as PSQLError where error.isUniqueViolation && error.constraintName == "users_email_key" {
            throw AppError.conflict(
                code: APIErrorCode.emailTaken,
                message: "An account with this email already exists. Sign in using its original method.")
        }
        return try await auth.issueTokens(for: userID)
    }
}
