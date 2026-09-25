import BrewlyAPI
@testable import BrewlyNetworking
import Foundation
import Testing

/// Serves canned responses to `URLSession` and records the requests it receives.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> (Int, Data)
    nonisolated(unsafe) static var handler: Handler?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else { return }
        Self.lastRequest = request
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

actor StubTokenProvider: AuthTokenProvider {
    private(set) var token = "expired"
    private(set) var refreshCount = 0

    func accessToken() async -> String? { token }

    func refreshAccessToken() async throws -> String {
        refreshCount += 1
        token = "fresh"
        return token
    }
}

@Suite("APIClient", .serialized)
struct APIClientTests {
    private let baseURL = URL(string: "https://api.brewly.test")!

    @Test("Decodes responses and sends the bearer token")
    func decodesResponses() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"methodSlugs":["v60","espresso"]}"#.utf8))
        }
        let client = APIClient(baseURL: baseURL, session: StubURLProtocol.session(), tokenProvider: StubTokenProvider())
        let methods = try await client.send(Endpoints.myMethods)
        #expect(methods.methodSlugs == ["v60", "espresso"])
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer expired")
        #expect(StubURLProtocol.lastRequest?.url?.path == "/v1/me/methods")
    }

    @Test("Refreshes the session once on 401 and retries")
    func refreshesOn401() async throws {
        StubURLProtocol.handler = { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh" {
                return (204, Data())
            }
            return (401, Data(#"{"code":"unauthorized","message":"Authentication is required."}"#.utf8))
        }
        let tokens = StubTokenProvider()
        let client = APIClient(baseURL: baseURL, session: StubURLProtocol.session(), tokenProvider: tokens)
        _ = try await client.send(Endpoints.deleteMe)
        #expect(await tokens.refreshCount == 1)
    }

    @Test("Surfaces API errors with their body")
    func surfacesErrors() async {
        StubURLProtocol.handler = { _ in
            (409, Data(#"{"code":"bean_in_use","message":"In use."}"#.utf8))
        }
        let client = APIClient(baseURL: baseURL, session: StubURLProtocol.session(), tokenProvider: StubTokenProvider())
        await #expect(throws: APIError.http(status: 409, body: APIErrorResponse(code: "bean_in_use", message: "In use."))) {
            _ = try await client.send(Endpoints.deleteBean(id: UUID()))
        }
    }

    @Test("Encodes query items and JSON bodies")
    func buildsRequests() throws {
        let client = APIClient(baseURL: baseURL)
        let request = try client.makeRequest(
            for: Endpoints.exploreRecipes(methodSlug: "v60", countryCode: nil, varietalSlug: nil, cursor: "abc"),
            token: nil
        )
        #expect(request.url?.absoluteString == "https://api.brewly.test/v1/recipes?method=v60&cursor=abc")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let login = try client.makeRequest(for: Endpoints.login(LoginRequest(email: "a@b.co", password: "x")), token: nil)
        #expect(login.httpMethod == "POST")
        #expect(String(data: login.httpBody ?? Data(), encoding: .utf8) == #"{"email":"a@b.co","password":"x"}"#)
    }
}
