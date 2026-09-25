import BrewlyAPI
import Vapor

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
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
