import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

/// Uploaded images, stored in PostgreSQL and served at `/v1/media/{id}`.
protocol MediaRepository: Sendable {
    func create(ownerID: UUID, jpeg: Data, width: Int, height: Int) async throws -> MediaDTO
    /// The image bytes if the viewer may see them: their own upload, a visible avatar or a photo of
    /// a visible post, brew, bean or recipe.
    func data(id: UUID, viewerID: UUID) async throws -> Data?
    /// Deletes the owner's uploads that are not used anywhere (see `media_in_use`).
    func deleteUnusedUploads(ownerID: UUID, olderThan age: TimeInterval) async throws
    /// Sets the user's avatar; `false` when the image is not the user's or is already used elsewhere.
    func setAvatar(userID: UUID, mediaID: UUID?) async throws -> Bool
}

struct PostgresMediaRepository: MediaRepository {
    let database: any Database

    static func url(for id: UUID) -> String {
        "/v1/media/\(id.uuidString.lowercased())"
    }

    func create(ownerID: UUID, jpeg: Data, width: Int, height: Int) async throws -> MediaDTO {
        guard let row = try await database.sql.raw("""
            INSERT INTO media (owner_id, content_type, data, width, height)
            VALUES (\(bind: ownerID), 'image/jpeg', \(bind: jpeg), \(bind: width), \(bind: height))
            RETURNING id
            """).first()
        else { throw AppError(status: .internalServerError, code: APIErrorCode.internalError, message: "Image was not stored.") }
        let id = try row.decode(column: "id", as: UUID.self)
        return MediaDTO(id: id, url: Self.url(for: id), width: width, height: height)
    }

    func data(id: UUID, viewerID: UUID) async throws -> Data? {
        try await database.sql.raw("""
            SELECT m.data FROM media m
            WHERE m.id = \(bind: id)
              AND (
                m.owner_id = \(bind: viewerID)
                OR EXISTS (SELECT 1 FROM users u
                           WHERE u.avatar_media_id = m.id AND can_view_content(\(bind: viewerID), u.id, 'public'))
                OR EXISTS (SELECT 1 FROM post_media pm JOIN posts p ON p.id = pm.post_id
                           WHERE pm.media_id = m.id AND can_view_content(\(bind: viewerID), p.author_id, p.visibility))
                OR EXISTS (SELECT 1 FROM brew_logs bl
                           WHERE bl.photo_media_id = m.id
                             AND can_view_content(\(bind: viewerID), bl.user_id, bl.visibility))
                OR EXISTS (SELECT 1 FROM coffee_beans cb
                           WHERE cb.photo_media_id = m.id
                             AND can_view_content(\(bind: viewerID), cb.owner_id, cb.visibility))
                OR EXISTS (SELECT 1 FROM recipes rc
                           WHERE rc.cover_media_id = m.id
                             AND can_view_content(\(bind: viewerID), rc.author_id, rc.visibility))
              )
            """).first().map { try $0.decode(column: "data", as: Data.self) }
    }

    func deleteUnusedUploads(ownerID: UUID, olderThan age: TimeInterval) async throws {
        try await database.sql.raw("""
            DELETE FROM media m
            WHERE m.owner_id = \(bind: ownerID)
              AND m.created_at < now() - make_interval(secs => \(bind: age))
              AND NOT media_in_use(m.id)
            """).run()
    }

    func setAvatar(userID: UUID, mediaID: UUID?) async throws -> Bool {
        try await database.transaction { tx in
            let sql = tx.sql
            let previous = try await sql.raw("SELECT avatar_media_id FROM users WHERE id = \(bind: userID)")
                .first()
                .flatMap { try $0.decode(column: "avatar_media_id", as: UUID?.self) }
            let updated = try await sql.raw("""
                UPDATE users SET avatar_media_id = \(bind: mediaID)
                WHERE id = \(bind: userID)
                  AND (\(bind: mediaID)::uuid IS NULL OR EXISTS (
                        SELECT 1 FROM media m
                        WHERE m.id = \(bind: mediaID) AND m.owner_id = \(bind: userID)
                          AND (NOT media_in_use(m.id) OR m.id IS NOT DISTINCT FROM \(bind: previous)::uuid)))
                RETURNING id
                """).first()
            guard updated != nil else { return false }
            // The previous picture is no longer used anywhere.
            if let previous, previous != mediaID {
                try await sql.raw("DELETE FROM media WHERE id = \(bind: previous)").run()
            }
            return true
        }
    }
}

/// The image is not one of the member's unused uploads.
struct UnavailableMediaError: Error {}

extension PostgresMediaRepository {
    /// Throws `UnavailableMediaError` unless `mediaID` is an unused upload of `ownerID`. The image
    /// the row already has (`current`) is accepted as is.
    static func checkUsable(_ mediaID: UUID?, ownerID: UUID, current: UUID?, sql: any SQLDatabase) async throws {
        guard let mediaID, mediaID != current else { return }
        let usable = try await sql.raw("""
            SELECT 1 FROM media
            WHERE id = \(bind: mediaID) AND owner_id = \(bind: ownerID) AND NOT media_in_use(id)
            """).first()
        guard usable != nil else { throw UnavailableMediaError() }
    }

    /// Deletes the image a row no longer uses after it was replaced or removed.
    static func deleteReplaced(_ previous: UUID?, by new: UUID?, sql: any SQLDatabase) async throws {
        guard let previous, previous != new else { return }
        try await sql.raw("DELETE FROM media WHERE id = \(bind: previous)").run()
    }
}
