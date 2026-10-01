import Foundation

public struct SignInChallenge: Sendable, Equatable {
    public var id: UUID
    public var nonce: String
    public var expiresAt: Date
    public init(id: UUID, nonce: String, expiresAt: Date) {
        self.id = id
        self.nonce = nonce
        self.expiresAt = expiresAt
    }
}

public struct ProviderCredential: Sendable, Equatable {
    public var identityToken: String
    public var authorizationCode: String?
    public var firstName: String?
    public var lastName: String?
    public init(
        identityToken: String, authorizationCode: String? = nil, firstName: String? = nil, lastName: String? = nil
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.firstName = firstName
        self.lastName = lastName
    }
}

/// Provider SDKs and presentation remain outside the feature module.
@MainActor
public protocol ProviderAuthorizing: Sendable {
    func authorize(provider: IdentityProvider, nonce: String) async throws -> ProviderCredential
}

public protocol FederatedAuthRepository: Sendable {
    func challenge(provider: IdentityProvider) async throws -> SignInChallenge
    func signIn(provider: IdentityProvider, challengeID: UUID, credential: ProviderCredential) async throws
        -> UserProfile
}

@MainActor
public struct FederatedSignInUseCase: Sendable {
    private let auth: any FederatedAuthRepository
    private let provider: any ProviderAuthorizing
    public init(auth: any FederatedAuthRepository, provider: any ProviderAuthorizing) {
        self.auth = auth
        self.provider = provider
    }
    public func callAsFunction(_ identityProvider: IdentityProvider) async throws -> UserProfile {
        let challenge = try await auth.challenge(provider: identityProvider)
        let credential = try await provider.authorize(provider: identityProvider, nonce: challenge.nonce)
        try Task.checkCancellation()
        return try await auth.signIn(provider: identityProvider, challengeID: challenge.id, credential: credential)
    }
}
