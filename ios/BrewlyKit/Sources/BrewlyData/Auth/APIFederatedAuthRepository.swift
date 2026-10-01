import BrewlyAPI
import BrewlyDomain
import BrewlyNetworking
import Foundation

public struct APIFederatedAuthRepository: FederatedAuthRepository {
    private let client: APIClient
    private let session: SessionManager
    public init(client: APIClient, session: SessionManager) {
        self.client = client
        self.session = session
    }

    public func challenge(provider: IdentityProvider) async throws -> SignInChallenge {
        try await mappingErrors {
            let challenge = try await client.send(Endpoints.authChallenge(AuthChallengeRequest(provider: provider)))
            return SignInChallenge(id: challenge.id, nonce: challenge.nonce, expiresAt: challenge.expiresAt)
        }
    }

    public func signIn(provider: IdentityProvider, challengeID: UUID, credential: ProviderCredential) async throws
        -> UserProfile
    {
        try await mappingErrors {
            let response = try await client.send(
                Endpoints.federatedSignIn(
                    provider: provider,
                    body: FederatedSignInRequest(
                        challengeId: challengeID, identityToken: credential.identityToken,
                        authorizationCode: credential.authorizationCode, firstName: credential.firstName,
                        lastName: credential.lastName
                    )))
            await session.start(with: response)
            return UserProfile(response.user)
        }
    }
}
