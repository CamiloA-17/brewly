import FluentKit
import SQLKit
import Vapor

enum RefreshTokenLookup: Equatable, Sendable {
    /// The token was valid and has now been consumed.
    case valid(userID: UUID)
    /// The token had already been used: a sign that it leaked.
    case reused(userID: UUID)
    /// Unknown or expired.
    case invalid
}

struct PasswordCredentials: Sendable {
    var userID: UUID
    var passwordHash: String
}

protocol AuthRepository: Sendable {
    /// Creates the user and its password identity atomically. Returns the new user id.
    func createPasswordUser(email: String, username: String, displayName: String, passwordHash: String) async throws -> UUID
    func passwordCredentials(email: String) async throws -> PasswordCredentials?
    func storeRefreshToken(userID: UUID, tokenHash: String, expiresAt: Date) async throws
    func consumeRefreshToken(tokenHash: String) async throws -> RefreshTokenLookup
    func revokeRefreshToken(tokenHash: String) async throws
    func revokeAllRefreshTokens(userID: UUID) async throws
}

struct PostgresAuthRepository: AuthRepository {
    let database: any Database

    func createPasswordUser(email: String, username: String, displayName: String, passwordHash: String) async throws -> UUID {
        try await database.transaction { tx in
            guard let row = try await tx.sql.raw("""
                INSERT INTO users (username, display_name, email)
                VALUES (\(bind: username), \(bind: displayName), \(bind: email))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: "internal_error", message: "User was not created.") }
            let userID = try row.decode(column: "id", as: UUID.self)
            try await tx.sql.raw("""
                INSERT INTO auth_identities (user_id, provider, subject, password_hash)
                VALUES (\(bind: userID), 'password', \(bind: email), \(bind: passwordHash))
                """).run()
            return userID
        }
    }

    func passwordCredentials(email: String) async throws -> PasswordCredentials? {
        guard let row = try await database.sql.raw("""
            SELECT user_id, password_hash FROM auth_identities
            WHERE provider = 'password' AND subject = \(bind: email)
            """).first()
        else { return nil }
        return PasswordCredentials(
            userID: try row.decode(column: "user_id", as: UUID.self),
            passwordHash: try row.decode(column: "password_hash", as: String.self)
        )
    }

    func storeRefreshToken(userID: UUID, tokenHash: String, expiresAt: Date) async throws {
        try await database.sql.raw("""
            INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
            VALUES (\(bind: userID), \(bind: tokenHash), \(bind: expiresAt))
            """).run()
    }

    func consumeRefreshToken(tokenHash: String) async throws -> RefreshTokenLookup {
        // Single statement, so two concurrent refreshes cannot both succeed.
        if let row = try await database.sql.raw("""
            UPDATE refresh_tokens SET revoked_at = now()
            WHERE token_hash = \(bind: tokenHash) AND revoked_at IS NULL AND expires_at > now()
            RETURNING user_id
            """).first() {
            return .valid(userID: try row.decode(column: "user_id", as: UUID.self))
        }
        guard let row = try await database.sql.raw("""
            SELECT user_id FROM refresh_tokens
            WHERE token_hash = \(bind: tokenHash) AND revoked_at IS NOT NULL
            """).first()
        else { return .invalid }
        return .reused(userID: try row.decode(column: "user_id", as: UUID.self))
    }

    func revokeRefreshToken(tokenHash: String) async throws {
        try await database.sql.raw("""
            UPDATE refresh_tokens SET revoked_at = now()
            WHERE token_hash = \(bind: tokenHash) AND revoked_at IS NULL
            """).run()
    }

    func revokeAllRefreshTokens(userID: UUID) async throws {
        try await database.sql.raw("""
            UPDATE refresh_tokens SET revoked_at = now()
            WHERE user_id = \(bind: userID) AND revoked_at IS NULL
            """).run()
    }
}
