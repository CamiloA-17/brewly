import BrewlyAPI
import BrewlyNetworking
import Foundation

/// Owns the session tokens and renews the access token when it expires.
///
/// Concurrent 401s share a single refresh request ("single-flight"). When the refresh
/// token is rejected, the session is cleared and `sessionExpired` emits.
public actor SessionManager: AuthTokenProvider {
    private let client: APIClient
    private let store: any TokenStore
    private var refreshTask: Task<String, any Error>?
    private let expiredContinuation: AsyncStream<Void>.Continuation

    /// Emits every time the session ends without the user signing out.
    public nonisolated let sessionExpired: AsyncStream<Void>

    /// - Parameter client: a client *without* a token provider, used to call `/auth/refresh`.
    public init(client: APIClient, store: any TokenStore) {
        self.client = client
        self.store = store
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        self.sessionExpired = stream
        self.expiredContinuation = continuation
    }

    public var hasSession: Bool {
        store.load() != nil
    }

    public func accessToken() async -> String? {
        store.load()?.accessToken
    }

    public func refreshAccessToken() async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// Stores the tokens of a successful sign-in, sign-up or refresh.
    public func start(with auth: AuthResponse) {
        store.save(StoredTokens(
            accessToken: auth.accessToken,
            accessTokenExpiresAt: auth.accessTokenExpiresAt,
            refreshToken: auth.refreshToken
        ))
    }

    /// Revokes the refresh token on the server (best effort) and forgets the session.
    public func end() async {
        if let refreshToken = store.load()?.refreshToken {
            _ = try? await client.send(Endpoints.logout(RefreshTokenRequest(refreshToken: refreshToken)))
        }
        store.clear()
    }

    /// Forgets the session locally without contacting the server (e.g. after deleting the account).
    public func discard() {
        store.clear()
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = store.load()?.refreshToken else {
            throw APIError.unauthorized
        }
        do {
            let auth = try await client.send(Endpoints.refresh(RefreshTokenRequest(refreshToken: refreshToken)))
            start(with: auth)
            return auth.accessToken
        } catch let error as APIError {
            if case .transport = error { throw error }
            // The refresh token was rejected: the session is over.
            store.clear()
            expiredContinuation.yield()
            throw APIError.unauthorized
        }
    }
}
