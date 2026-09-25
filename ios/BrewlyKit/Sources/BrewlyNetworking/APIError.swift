import BrewlyAPI
import Foundation

public enum APIError: Error, Sendable, Equatable {
    /// The request never got an HTTP response (offline, timeout, DNS…).
    case transport(URLError.Code)
    /// 401 that could not be recovered by refreshing the session.
    case unauthorized
    /// Any other non-2xx response, with the decoded error body when available.
    case http(status: Int, body: APIErrorResponse?)
    /// The response body did not match the expected type.
    case decoding(String)
}
