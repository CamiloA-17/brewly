import Foundation

public struct AuthChallengeRequest: Codable, Sendable, Equatable {
    public var provider: IdentityProvider
    public init(provider: IdentityProvider) { self.provider = provider }
}

public struct AuthChallengeResponse: Codable, Sendable, Equatable {
    public var id: UUID
    /// Send this exact value as the provider's nonce; do not hash it on the client.
    public var nonce: String
    public var expiresAt: Date
    public init(id: UUID, nonce: String, expiresAt: Date) {
        self.id = id
        self.nonce = nonce
        self.expiresAt = expiresAt
    }
}

/// POST /auth/apple or /auth/google. Email always comes from the verified ID token.
public struct FederatedSignInRequest: Codable, Sendable, Equatable {
    public var challengeId: UUID
    public var identityToken: String
    /// Required for Apple: exchanged for an encrypted revocable provider refresh token.
    public var authorizationCode: String?
    /// Apple supplies these only on the first authorization. They are untrusted profile hints.
    public var firstName: String?
    public var lastName: String?
    public init(
        challengeId: UUID, identityToken: String, authorizationCode: String? = nil,
        firstName: String? = nil, lastName: String? = nil
    ) {
        self.challengeId = challengeId
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.firstName = firstName
        self.lastName = lastName
    }
}
