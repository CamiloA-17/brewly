import BrewlyAPI
@testable import BrewlyData
import BrewlyDomain
import BrewlyNetworking
import Foundation
import Testing

final class RefreshStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        // Answer slowly so concurrent refreshes overlap.
        Thread.sleep(forTimeInterval: 0.2)
        let body = Self.status == 200 ? Self.authResponse : Data(#"{"code":"unauthorized","message":"No."}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static let authResponse = Data("""
    {
      "accessToken": "new-access",
      "accessTokenExpiresAt": "2026-09-25T10:15:00Z",
      "refreshToken": "new-refresh",
      "refreshTokenExpiresAt": "2026-10-25T10:00:00Z",
      "user": {
        "id": "11111111-1111-4111-8111-111111111111",
        "username": "ana.barista",
        "displayName": "Ana",
        "createdAt": "2026-09-01T00:00:00Z"
      }
    }
    """.utf8)
}

@Suite("SessionManager", .serialized)
struct SessionManagerTests {
    private func makeManager(store: InMemoryTokenStore) -> SessionManager {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshStubProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://api.brewly.test")!, session: URLSession(configuration: configuration))
        return SessionManager(client: client, store: store)
    }

    private let stored = StoredTokens(accessToken: "old-access", accessTokenExpiresAt: Date(), refreshToken: "old-refresh")

    @Test("Concurrent refreshes share one request and store the new tokens")
    func singleFlightRefresh() async throws {
        RefreshStubProtocol.status = 200
        RefreshStubProtocol.requestCount = 0
        let store = InMemoryTokenStore(tokens: stored)
        let manager = makeManager(store: store)

        async let first = manager.refreshAccessToken()
        async let second = manager.refreshAccessToken()
        let tokens = try await [first, second]

        #expect(tokens == ["new-access", "new-access"])
        #expect(RefreshStubProtocol.requestCount == 1)
        #expect(store.load()?.refreshToken == "new-refresh")
    }

    @Test("A rejected refresh token ends the session")
    func rejectedRefresh() async {
        RefreshStubProtocol.status = 401
        let store = InMemoryTokenStore(tokens: stored)
        let manager = makeManager(store: store)

        await #expect(throws: APIError.unauthorized) {
            _ = try await manager.refreshAccessToken()
        }
        #expect(store.load() == nil)
    }
}

@Suite("Error mapping")
struct ErrorMappingTests {
    @Test("HTTP errors become domain errors")
    func mapsErrors() {
        #expect(DomainError.from(APIError.transport(.notConnectedToInternet)) == .offline)
        #expect(DomainError.from(APIError.http(status: 404, body: nil)) == .notFound)
        #expect(DomainError.from(APIError.http(
            status: 409, body: APIErrorResponse(code: "bean_in_use", message: "In use.")
        )) == .conflict(code: "bean_in_use"))
        #expect(DomainError.from(APIError.http(
            status: 401, body: APIErrorResponse(code: "invalid_credentials", message: "No.")
        )) == .invalidCredentials)
        let validation = DomainError.from(APIError.http(status: 422, body: APIErrorResponse(
            code: "validation_failed", message: "Invalid.",
            fieldErrors: [.init(field: "doseG", code: "required", message: "Required.")]
        )))
        #expect(validation == .validation([RuleViolation(field: "doseG", kind: .required)]))
    }
}
