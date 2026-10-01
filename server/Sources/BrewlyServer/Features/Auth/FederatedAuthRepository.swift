import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

struct VerifiedIdentity: Sendable {
    var provider: IdentityProvider
    var subject: String
    var email: String?
    var nonce: String
    var firstName: String?
    var lastName: String?
    var encryptedRefreshToken: String?
}

protocol FederatedAuthRepository: Sendable {
    func createChallenge(provider: IdentityProvider, nonceHash: String, expiresAt: Date) async throws -> UUID
    func consumeChallenge(id: UUID, provider: IdentityProvider, nonceHash: String) async throws -> Bool
    func resolveUser(_ identity: VerifiedIdentity) async throws -> UUID
    func appleRefreshToken(userID: UUID) async throws -> String?
}

struct PostgresFederatedAuthRepository: FederatedAuthRepository {
    let database: any Database

    func createChallenge(provider: IdentityProvider, nonceHash: String, expiresAt: Date) async throws -> UUID {
        try await database.sql.raw("DELETE FROM auth_challenges WHERE expires_at <= now()").run()
        guard
            let row = try await database.sql.raw(
                """
                INSERT INTO auth_challenges (provider, nonce_hash, expires_at)
                VALUES (\(bind: provider.rawValue), \(bind: nonceHash), \(bind: expiresAt)) RETURNING id
                """
            ).first()
        else { throw AppError.unauthorized }
        return try row.decode(column: "id", as: UUID.self)
    }

    func consumeChallenge(id: UUID, provider: IdentityProvider, nonceHash: String) async throws -> Bool {
        try await database.sql.raw(
            """
            DELETE FROM auth_challenges WHERE id = \(bind: id) AND provider = \(bind: provider.rawValue)
                AND nonce_hash = \(bind: nonceHash) AND expires_at > now() RETURNING id
            """
        ).first() != nil
    }

    func resolveUser(_ identity: VerifiedIdentity) async throws -> UUID {
        try await database.transaction { tx in
            // Serialize first sign-ins for the same provider subject, including across API instances.
            try await tx.sql.raw(
                """
                SELECT pg_advisory_xact_lock(hashtextextended(\(bind: identity.provider.rawValue + ":" + identity.subject), 0))
                """
            ).run()
            if let row = try await tx.sql.raw(
                """
                SELECT user_id FROM auth_identities
                WHERE provider = \(bind: identity.provider.rawValue) AND subject = \(bind: identity.subject)
                """
            ).first() {
                let id = try row.decode(column: "user_id", as: UUID.self)
                if identity.provider == .apple, let refreshToken = identity.encryptedRefreshToken {
                    try await tx.sql.raw(
                        """
                        UPDATE auth_identities SET provider_refresh_token = \(bind: refreshToken)
                        WHERE user_id = \(bind: id) AND provider = 'apple'
                        """
                    ).run()
                }
                return id
            }
            guard let email = identity.email else { throw AppError.invalidCredentials }
            let id = UUID()
            let username = "brewer_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(23)
            let firstName = identity.firstName.nilIfBlank.map { String($0.prefix(60)) }
            let lastName = identity.lastName.nilIfBlank.map { String($0.prefix(60)) }
            let displayName = String(
                ([firstName, lastName].compactMap { $0 }.joined(separator: " ")
                    .nilIfBlank ?? "Brewer").prefix(60))
            // Never attach by email. Its unique constraint rejects a collision with an existing account.
            try await tx.sql.raw(
                """
                INSERT INTO users (id, username, display_name, email, first_name, last_name)
                VALUES (\(bind: id), \(bind: String(username)), \(bind: displayName), \(bind: email),
                        \(bind: firstName), \(bind: lastName))
                """
            ).run()
            let appleEmail = identity.provider == .apple ? email : nil
            try await tx.sql.raw(
                """
                INSERT INTO auth_identities (user_id, provider, subject, provider_email, provider_refresh_token)
                VALUES (\(bind: id), \(bind: identity.provider.rawValue), \(bind: identity.subject),
                        \(bind: appleEmail), \(bind: identity.encryptedRefreshToken))
                """
            ).run()
            return id
        }
    }

    func appleRefreshToken(userID: UUID) async throws -> String? {
        guard
            let row = try await database.sql.raw(
                """
                SELECT provider_refresh_token FROM auth_identities WHERE user_id = \(bind: userID) AND provider = 'apple'
                """
            ).first()
        else { return nil }
        return try row.decode(column: "provider_refresh_token", as: String?.self)
    }
}
