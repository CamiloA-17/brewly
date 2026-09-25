import BrewlyAPI
import Vapor

extension Response {
    /// A JSON response encoded with the shared API coders (ISO 8601 dates).
    static func json<Body: Encodable>(_ body: Body, status: HTTPResponseStatus = .ok) throws -> Response {
        let response = Response(status: status)
        try response.content.encode(body, using: BrewlyJSON.makeEncoder())
        return response
    }
}

extension Request {
    /// Decodes the JSON body with the shared API coders.
    func decodeJSON<Body: Decodable>(_ type: Body.Type) throws -> Body {
        try content.decode(type, using: BrewlyJSON.makeDecoder())
    }

    /// A UUID path parameter, or 404 when it is missing or malformed.
    func uuidParameter(_ name: String, resource: String) throws -> UUID {
        guard let value = parameters.get(name), let id = UUID(uuidString: value) else {
            throw AppError.notFound(resource)
        }
        return id
    }

    /// `?limit=` clamped to `1...50` (default 20).
    var pageLimit: Int {
        min(max(query[Int.self, at: "limit"] ?? 20, 1), 50)
    }
}
