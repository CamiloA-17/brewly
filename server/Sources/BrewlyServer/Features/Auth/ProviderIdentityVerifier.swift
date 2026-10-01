import BrewlyAPI
import JWT
import Vapor

struct ProviderIdentityVerifier: IdentityTokenVerifying {
    let request: Request

    func requireConfiguration(provider: IdentityProvider) throws {
        let config = request.application.appConfig
        guard provider == .apple ? config.apple != nil : config.googleClientID != nil else {
            throw AppError(
                status: .serviceUnavailable, code: APIErrorCode.identityProviderUnavailable,
                message: "This sign-in provider has not been configured.")
        }
    }

    func verify(_ token: String, provider: IdentityProvider) async throws -> VerifiedIdentity {
        try requireConfiguration(provider: provider)
        let keys: JWTKeyCollection
        let clientID: String
        switch provider {
        case .apple:
            keys = try await request.application.jwt.apple.keys(on: request)
            clientID = request.application.appConfig.apple!.clientID
        case .google:
            keys = try await request.application.jwt.google.keys(on: request)
            clientID = request.application.appConfig.googleClientID!
        }
        return try await ProviderTokenVerifier.verify(token, provider: provider, keys: keys, clientID: clientID)
    }

    func exchangeAppleCode(_ code: String, identity: VerifiedIdentity) async throws -> String {
        guard let config = request.application.appConfig.apple else {
            try requireConfiguration(provider: .apple)
            throw AppError.unauthorized
        }
        let secret = try await clientSecret(config)
        let response = try await request.client.post("https://appleid.apple.com/auth/token") { req in
            try req.content.encode(
                [
                    "client_id": config.clientID, "client_secret": secret,
                    "code": code, "grant_type": "authorization_code",
                ], as: .urlEncodedForm)
        }
        guard response.status == .ok else { throw AppError.invalidCredentials }
        let tokens = try response.content.decode(AppleTokenResponse.self)
        let exchanged = try await verify(tokens.idToken, provider: .apple)
        guard exchanged.subject == identity.subject, exchanged.nonce == identity.nonce,
            let refreshToken = tokens.refreshToken, !refreshToken.isEmpty
        else { throw AppError.invalidCredentials }
        return try ProviderTokenCipher(key: config.encryptionKey).encrypt(refreshToken)
    }

    /// Revoke before deleting local data; preserve the account if the provider is unavailable.
    func revokeAppleAuthorization(userID: UUID) async throws {
        let repository = PostgresFederatedAuthRepository(database: request.db)
        guard let encrypted = try await repository.appleRefreshToken(userID: userID) else { return }
        try requireConfiguration(provider: .apple)
        let config = request.application.appConfig.apple!
        let token = try ProviderTokenCipher(key: config.encryptionKey).decrypt(encrypted)
        let secret = try await clientSecret(config)
        let response = try await request.client.post("https://appleid.apple.com/auth/revoke") { req in
            try req.content.encode(
                [
                    "client_id": config.clientID, "client_secret": secret,
                    "token": token, "token_type_hint": "refresh_token",
                ], as: .urlEncodedForm)
        }
        guard response.status == .ok else {
            throw AppError(
                status: .serviceUnavailable, code: APIErrorCode.identityProviderUnavailable,
                message: "Apple authorization could not be revoked. Please try deleting the account again.")
        }
    }

    private func clientSecret(_ config: AppleAuthConfig) async throws -> String {
        let keys = JWTKeyCollection()
        let kid = JWKIdentifier(string: config.keyID)
        await keys.add(ecdsa: config.privateKey, kid: kid)
        let now = Date()
        return try await keys.sign(
            AppleClientSecret(
                issuer: .init(value: config.teamID),
                subject: .init(value: config.clientID), audience: "https://appleid.apple.com",
                issuedAt: .init(value: now), expires: .init(value: now.addingTimeInterval(5 * 60))), kid: kid)
    }
}

private struct AppleTokenResponse: Content {
    let idToken: String
    let refreshToken: String?
    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case refreshToken = "refresh_token"
    }
}

private struct AppleClientSecret: JWTPayload {
    let issuer: IssuerClaim
    let subject: SubjectClaim
    let audience: AudienceClaim
    let issuedAt: IssuedAtClaim
    let expires: ExpirationClaim
    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case audience = "aud"
        case issuedAt = "iat"
        case expires = "exp"
    }
    func verify(using algorithm: some JWTAlgorithm) async throws { try expires.verifyNotExpired() }
}
