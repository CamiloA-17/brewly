import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Response type for endpoints that return no body (204).
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

/// A non-JSON request body, e.g. an image upload.
public struct RawBody: Sendable {
    public var data: Data
    public var contentType: String

    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

/// A typed description of one API call. Use `Data` as the response type to receive raw bytes.
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var method: HTTPMethod
    /// Path relative to the base URL, without a leading slash (e.g. `"v1/beans"`).
    public var path: String
    public var queryItems: [URLQueryItem]
    public var body: (any Encodable & Sendable)?
    /// Sent instead of `body` when set.
    public var rawBody: RawBody?
    /// Whether the request needs `Authorization: Bearer <access token>`.
    public var requiresAuth: Bool

    public init(
        _ method: HTTPMethod,
        _ path: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil,
        rawBody: RawBody? = nil,
        requiresAuth: Bool = true
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.rawBody = rawBody
        self.requiresAuth = requiresAuth
    }
}
