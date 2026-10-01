import BrewlyAPI
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("challenge", use: challenge)
        auth.post("apple", use: apple)
        auth.post("google", use: google)
        auth.post("refresh", use: refresh)
        auth.post("logout", use: logout)
    }

    @Sendable
    func register(req: Request) async throws -> Response {
        let response = try await service(req).register(try req.decodeJSON(RegisterRequest.self))
        return try .json(response, status: .created)
    }

    @Sendable
    func login(req: Request) async throws -> Response {
        try .json(try await service(req).login(try req.decodeJSON(LoginRequest.self)))
    }

    @Sendable
    func refresh(req: Request) async throws -> Response {
        try .json(try await service(req).refresh(try req.decodeJSON(RefreshTokenRequest.self)))
    }

    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        try await service(req).logout(try req.decodeJSON(RefreshTokenRequest.self))
        return .noContent
    }

    @Sendable
    func challenge(req: Request) async throws -> Response {
        try .json(try await federatedService(req).challenge(try req.decodeJSON(AuthChallengeRequest.self)))
    }

    @Sendable
    func apple(req: Request) async throws -> Response {
        try .json(try await federatedService(req).signIn(try req.decodeJSON(FederatedSignInRequest.self), provider: .apple))
    }

    @Sendable
    func google(req: Request) async throws -> Response {
        try .json(try await federatedService(req).signIn(try req.decodeJSON(FederatedSignInRequest.self), provider: .google))
    }

    private func federatedService(_ req: Request) -> FederatedAuthService {
        FederatedAuthService(repository: PostgresFederatedAuthRepository(database: req.db),
            verifier: ProviderIdentityVerifier(request: req), auth: service(req))
    }

    private func service(_ req: Request) -> AuthService {
        let config = req.application.appConfig
        return AuthService(
            auth: PostgresAuthRepository(database: req.db),
            users: PostgresUserRepository(database: req.db),
            passwords: RequestPasswordHashing(request: req),
            tokens: TokenService(
                keys: req.application.jwt.keys,
                accessTokenTTL: config.accessTokenTTL,
                refreshTokenTTL: config.refreshTokenTTL
            )
        )
    }
}
