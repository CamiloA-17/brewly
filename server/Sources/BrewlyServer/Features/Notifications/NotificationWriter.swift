import BrewlyAPI
import Foundation
import SQLKit

/// Creates notifications in the same transaction as the action that causes them.
///
/// Nobody is notified about their own actions or by members they blocked (or who blocked them).
/// Follows, likes and saves are written with `ON CONFLICT DO NOTHING`, so undoing and redoing
/// them notifies once (`notifications_once_idx`); undoing them removes the notification.
enum NotificationWriter {
    /// Notifies the author of the post and, for a reply, the author of the comment replied to.
    static func commentAdded(commentID: UUID, sql: any SQLDatabase) async throws {
        try await sql.raw("""
            INSERT INTO notifications (recipient_id, actor_id, kind, post_id, comment_id)
            SELECT recipient.id, c.author_id, recipient.kind, c.post_id, c.id
            FROM comments c
            JOIN posts p ON p.id = c.post_id
            LEFT JOIN comments parent ON parent.id = c.parent_id
            CROSS JOIN LATERAL (
                -- The replied-to author gets a reply notification; the post author a comment one,
                -- unless they are the same person.
                SELECT parent.author_id AS id, 'comment_reply' AS kind WHERE parent.id IS NOT NULL
                UNION
                SELECT p.author_id, 'comment' WHERE parent.author_id IS DISTINCT FROM p.author_id
            ) recipient
            WHERE c.id = \(bind: commentID)
              AND recipient.id <> c.author_id
              AND can_view_content(recipient.id, c.author_id, 'public')
            """).run()
    }

    /// Tells the original author about a remix they are allowed to see.
    static func recipeForked(remixID: UUID, sql: any SQLDatabase) async throws {
        try await sql.raw("""
            INSERT INTO notifications (recipient_id, actor_id, kind, recipe_id)
            SELECT o.author_id, r.author_id, 'recipe_fork', r.id
            FROM recipes r
            JOIN recipes o ON o.id = r.forked_from_id
            WHERE r.id = \(bind: remixID)
              AND o.author_id <> r.author_id
              AND can_view_content(o.author_id, r.author_id, r.visibility)
            """).run()
    }
}
