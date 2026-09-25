/// Supplies access tokens to `APIClient` and renews them when they expire.
public protocol AuthTokenProvider: Sendable {
    /// The current access token, if the user is signed in.
    func accessToken() async -> String?
    /// Obtains a fresh access token. Throws `APIError.unauthorized` when the session is over.
    func refreshAccessToken() async throws -> String
}
