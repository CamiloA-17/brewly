import BrewlyDomain
import Foundation
import Testing

@testable import AuthFeature

@MainActor
@Suite("Federated sign-in")
struct FederatedSignInViewModelTests {
    @Test("Cancellation leaves no error or Brewly session")
    func cancellation() async {
        let auth = RecordingFederatedAuth()
        let provider = StubProvider(error: .signInCancelled)
        let model = FederatedSignInViewModel(signIn: FederatedSignInUseCase(auth: auth, provider: provider))
        #expect(await model.submit(.apple) == nil)
        #expect(model.errorMessage == nil)
        #expect(!model.isSubmitting)
        #expect(await auth.signIns == 0)
    }

    @Test("Provider unavailable is displayed and submission finishes")
    func unavailable() async {
        let model = FederatedSignInViewModel(
            signIn: FederatedSignInUseCase(
                auth: RecordingFederatedAuth(), provider: StubProvider(error: .authenticationUnavailable)))
        #expect(await model.submit(.google) == nil)
        #expect(model.errorMessage != nil)
        #expect(!model.isSubmitting)
    }

    @Test("The server nonce and provider credential reach sign-in, preserving onboarding")
    func successfulSignIn() async throws {
        let auth = RecordingFederatedAuth()
        let provider = StubProvider()
        let model = FederatedSignInViewModel(signIn: FederatedSignInUseCase(auth: auth, provider: provider))
        let user = try #require(await model.submit(.google))
        #expect(user.needsOnboarding)
        #expect(provider.nonce == "server-nonce")
        #expect(await auth.provider == .google)
        #expect(await auth.credential?.identityToken == "verified-by-server")
        #expect(await auth.challengeID == auth.id)
        #expect(model.errorMessage == nil)
    }
}

@MainActor
private final class StubProvider: ProviderAuthorizing {
    let error: DomainError?
    private(set) var nonce: String?
    init(error: DomainError? = nil) { self.error = error }
    func authorize(provider: IdentityProvider, nonce: String) async throws -> ProviderCredential {
        self.nonce = nonce
        if let error { throw error }
        return ProviderCredential(identityToken: "verified-by-server")
    }
}

private actor RecordingFederatedAuth: FederatedAuthRepository {
    nonisolated let id = UUID()
    private(set) var signIns = 0
    private(set) var provider: IdentityProvider?
    private(set) var credential: ProviderCredential?
    private(set) var challengeID: UUID?
    func challenge(provider: IdentityProvider) async throws -> SignInChallenge {
        SignInChallenge(id: id, nonce: "server-nonce", expiresAt: Date().addingTimeInterval(300))
    }
    func signIn(provider: IdentityProvider, challengeID: UUID, credential: ProviderCredential) async throws
        -> UserProfile
    {
        signIns += 1
        self.provider = provider
        self.credential = credential
        self.challengeID = challengeID
        return UserProfile(
            id: UUID(), username: "brewer", displayName: "Brewer", needsOnboarding: true, createdAt: Date())
    }
}
