import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

protocol NotificationRepository: Sendable {
    /// The user's notifications, newest first. Those from blocked members are hidden.
    func list(recipientID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<NotificationDTO>
    func unreadCount(recipientID: UUID) async throws -> Int
    func markAllRead(recipientID: UUID) async throws
}

struct PostgresNotificationRepository: NotificationRepository {
    let database: any Database

    /// Length of the post and comment excerpts.
    static let excerptLength = 80

    private struct Row: Decodable {
        var id: UUID
        var kind: String
        var createdAt: Date
        var cursorCreatedAt: String
        var isRead: Bool
        var actorId: UUID
        var actorUsername: String
        var actorDisplayName: String
        var actorAvatarUrl: String?
        var postId: UUID?
        var postExcerpt: String?
        var commentId: UUID?
        var commentExcerpt: String?
        var recipeId: UUID?
        var recipeTitle: String?

        var dto: NotificationDTO? {
            guard let kind = NotificationKind(rawValue: kind) else { return nil }
            return NotificationDTO(
                id: id,
                kind: kind,
                actor: UserSummaryDTO(
                    id: actorId, username: actorUsername, displayName: actorDisplayName, avatarURL: actorAvatarUrl
                ),
                postId: postId,
                postExcerpt: postExcerpt,
                commentId: commentId,
                commentExcerpt: commentExcerpt,
                recipeId: recipeId,
                recipeTitle: recipeTitle,
                isRead: isRead,
                createdAt: createdAt
            )
        }
    }

    func list(recipientID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<NotificationDTO> {
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let rows = try await database.sql.raw("""
            SELECT n.id, n.kind, n.created_at, \(unsafeRaw: PageCursor.sqlTimestamp("n.created_at")) AS cursor_created_at,
                   n.read_at IS NOT NULL AS is_read,
                   a.id AS actor_id, a.username AS actor_username, a.display_name AS actor_display_name,
                   a.avatar_url AS actor_avatar_url,
                   n.post_id, left(p.body, \(bind: Self.excerptLength)) AS post_excerpt,
                   n.comment_id, left(c.body, \(bind: Self.excerptLength)) AS comment_excerpt,
                   n.recipe_id, r.title AS recipe_title
            FROM notifications n
            JOIN users a ON a.id = n.actor_id
            LEFT JOIN posts p ON p.id = n.post_id
            LEFT JOIN comments c ON c.id = n.comment_id
            LEFT JOIN recipes r ON r.id = n.recipe_id
            WHERE n.recipient_id = \(bind: recipientID)
              AND can_view_content(\(bind: recipientID), n.actor_id, 'public')
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (n.created_at, n.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY n.created_at DESC, n.id DESC
            LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(Row.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorCreatedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.compactMap(\.dto), nextCursor: nextCursor)
    }

    func unreadCount(recipientID: UUID) async throws -> Int {
        let row = try await database.sql.raw("""
            SELECT count(*)::int AS count FROM notifications n
            WHERE n.recipient_id = \(bind: recipientID) AND n.read_at IS NULL
              AND can_view_content(\(bind: recipientID), n.actor_id, 'public')
            """).first()
        return try row?.decode(column: "count", as: Int.self) ?? 0
    }

    func markAllRead(recipientID: UUID) async throws {
        try await database.sql.raw("""
            UPDATE notifications SET read_at = now()
            WHERE recipient_id = \(bind: recipientID) AND read_at IS NULL
            """).run()
    }
}
