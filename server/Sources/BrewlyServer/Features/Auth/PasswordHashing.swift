import Vapor

protocol PasswordHashing: Sendable {
    func hash(_ password: String) async throws -> String
    func verify(_ password: String, against hash: String) async throws -> Bool
}

/// Uses the application's password hasher (Bcrypt by default), off the event loop.
struct RequestPasswordHashing: PasswordHashing {
    let request: Request

    func hash(_ password: String) async throws -> String {
        try await request.password.async.hash(password)
    }

    func verify(_ password: String, against hash: String) async throws -> Bool {
        try await request.password.async.verify(password, created: hash)
    }
}
