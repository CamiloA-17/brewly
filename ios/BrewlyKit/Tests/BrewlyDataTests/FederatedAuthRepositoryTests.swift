import BrewlyAPI
import BrewlyDomain
import BrewlyNetworking
import Foundation
import Testing

@testable import BrewlyData

@Suite("Federated auth API repository", .serialized)
struct FederatedAuthRepositoryTests {
    private func repository(store: InMemoryTokenStore) -> APIFederatedAuthRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FederatedStubProtocol.self]
        let client = APIClient(
            baseURL: URL(string: "https://api.brewly.test")!,
            session: URLSession(configuration: configuration))
        return APIFederatedAuthRepository(client: client, session: SessionManager(client: client, store: store))
    }

    @Test("A successful provider exchange persists only Brewly tokens")
    func persistsSession() async throws {
        FederatedStubProtocol.status = 200
        FederatedStubProtocol.body = RefreshStubProtocol.authResponse
        let store = InMemoryTokenStore()
        let user = try await repository(store: store).signIn(
            provider: .apple, challengeID: UUID(),
            credential: ProviderCredential(identityToken: "apple-token", authorizationCode: "apple-code"))
        #expect(user.username == "ana.barista")
        #expect(store.load()?.accessToken == "new-access")
        #expect(store.load()?.refreshToken == "new-refresh")
        let request = try #require(FederatedStubProtocol.lastRequest)
        #expect(request.url?.path == "/v1/auth/apple")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("A rejected exchange leaves no session")
    func rejectedExchange() async {
        FederatedStubProtocol.status = 401
        FederatedStubProtocol.body = Data(#"{"code":"invalid_credentials","message":"Invalid."}"#.utf8)
        let store = InMemoryTokenStore()
        await #expect(throws: DomainError.invalidCredentials) {
            _ = try await repository(store: store).signIn(
                provider: .google, challengeID: UUID(),
                credential: ProviderCredential(identityToken: "rejected-token"))
        }
        #expect(store.load() == nil)
    }

    @Test("Provider configuration errors are localized domain errors")
    func unavailableProvider() async {
        FederatedStubProtocol.status = 503
        FederatedStubProtocol.body = Data(#"{"code":"identity_provider_unavailable","message":"Unavailable."}"#.utf8)
        await #expect(throws: DomainError.authenticationUnavailable) {
            _ = try await repository(store: InMemoryTokenStore()).challenge(provider: .google)
        }
    }
}

private final class FederatedStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
