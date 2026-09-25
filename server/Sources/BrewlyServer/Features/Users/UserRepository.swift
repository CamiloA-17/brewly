import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

protocol UserRepository: Sendable {
    func find(id: UUID) async throws -> CurrentUserDTO?
    func updateProfile(id: UUID, displayName: String, bio: String?, location: String?) async throws -> CurrentUserDTO?
    func delete(id: UUID) async throws
    func methodSlugs(userID: UUID) async throws -> [String]
    /// Returns `false` when the method does not exist.
    func addMethod(userID: UUID, slug: String) async throws -> Bool
    func removeMethod(userID: UUID, slug: String) async throws
}

struct PostgresUserRepository: UserRepository {
    let database: any Database

    private struct UserRow: Decodable {
        var id: UUID
        var username: String
        var displayName: String
        var email: String?
        var bio: String?
        var avatarUrl: String?
        var location: String?
        var createdAt: Date

        var dto: CurrentUserDTO {
            CurrentUserDTO(
                id: id, username: username, displayName: displayName, email: email,
                bio: bio, avatarURL: avatarUrl, location: location, createdAt: createdAt
            )
        }
    }

    private static let columns = "id, username, display_name, email, bio, avatar_url, location, created_at"

    func find(id: UUID) async throws -> CurrentUserDTO? {
        try await database.sql.raw("SELECT \(unsafeRaw: Self.columns) FROM users WHERE id = \(bind: id)")
            .first()
            .map { try $0.decodeSnakeCase(UserRow.self).dto }
    }

    func updateProfile(id: UUID, displayName: String, bio: String?, location: String?) async throws -> CurrentUserDTO? {
        try await database.sql.raw("""
            UPDATE users
            SET display_name = \(bind: displayName), bio = \(bind: bio), location = \(bind: location)
            WHERE id = \(bind: id)
            RETURNING \(unsafeRaw: Self.columns)
            """)
            .first()
            .map { try $0.decodeSnakeCase(UserRow.self).dto }
    }

    func delete(id: UUID) async throws {
        try await database.sql.raw("DELETE FROM users WHERE id = \(bind: id)").run()
    }

    func methodSlugs(userID: UUID) async throws -> [String] {
        try await database.sql.raw("""
            SELECT m.slug
            FROM user_brew_methods um
            JOIN brew_methods m ON m.slug = um.method_slug
            WHERE um.user_id = \(bind: userID)
            ORDER BY m.sort_order, m.name
            """)
            .all()
            .map { try $0.decode(column: "slug", as: String.self) }
    }

    func addMethod(userID: UUID, slug: String) async throws -> Bool {
        let row = try await database.sql.raw("""
            INSERT INTO user_brew_methods (user_id, method_slug)
            SELECT \(bind: userID), slug FROM brew_methods WHERE slug = \(bind: slug)
            ON CONFLICT DO NOTHING
            RETURNING method_slug
            """).first()
        if row != nil { return true }
        // Either the method is unknown or it was already selected.
        return try await database.sql.raw("SELECT 1 FROM brew_methods WHERE slug = \(bind: slug)").first() != nil
    }

    func removeMethod(userID: UUID, slug: String) async throws {
        try await database.sql.raw(
            "DELETE FROM user_brew_methods WHERE user_id = \(bind: userID) AND method_slug = \(bind: slug)"
        ).run()
    }
}
