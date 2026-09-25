import BrewlyAPI
import Foundation

/// Sends typed `Endpoint`s to the Brewly API.
///
/// Authenticated requests carry the access token from `tokenProvider`; on a 401 the client
/// refreshes the session once and retries.
public final class APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: (any AuthTokenProvider)?

    public init(baseURL: URL, session: URLSession = .shared, tokenProvider: (any AuthTokenProvider)? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let token = endpoint.requiresAuth ? await tokenProvider?.accessToken() : nil
        var (data, response) = try await perform(makeRequest(for: endpoint, token: token))

        if response.statusCode == 401, endpoint.requiresAuth, let tokenProvider {
            let refreshedToken = try await tokenProvider.refreshAccessToken()
            (data, response) = try await perform(makeRequest(for: endpoint, token: refreshedToken))
        }

        return try decode(endpoint, data: data, response: response)
    }

    func makeRequest<Response>(for endpoint: Endpoint<Response>, token: String?) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else { throw APIError.transport(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let rawBody = endpoint.rawBody {
            request.setValue(rawBody.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = rawBody.data
        } else if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try BrewlyJSON.makeEncoder().encode(body)
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.transport(.badServerResponse)
            }
            return (data, httpResponse)
        } catch let error as URLError {
            throw APIError.transport(error.code)
        }
    }

    private func decode<Response>(_ endpoint: Endpoint<Response>, data: Data, response: HTTPURLResponse) throws -> Response {
        switch response.statusCode {
        case 200..<300:
            if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
                return empty
            }
            if let raw = data as? Response {
                return raw
            }
            do {
                return try BrewlyJSON.makeDecoder().decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401 where endpoint.requiresAuth:
            throw APIError.unauthorized
        default:
            let body = try? BrewlyJSON.makeDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.http(status: response.statusCode, body: body)
        }
    }
}
