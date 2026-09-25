import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

/// Which side of the follow graph a list returns.
enum FollowListKind: Sendable {
    /// People who follow the member.
    case followers
    /// People the member follows.
    case following
}

/// Other members: profiles, search and the follow graph.
///
/// Blocks hide members from each other everywhere. `can_view_content(viewer, member, 'public')`
/// is used as the block check because it is `true` exactly when no block exists between them.
protocol PeopleRepository: Sendable {
    /// `nil` when the member does not exist or a block exists between them and the viewer.
    func profile(id: UUID, viewerID: UUID) async throws -> UserProfileDTO?
    /// Members whose username or display name starts with `prefix`, excluding the viewer.
    func search(prefix: String, viewerID: UUID, limit: Int) async throws -> [UserSummaryDTO]
    func follows(of memberID: UUID, kind: FollowListKind, viewerID: UUID, after cursor: PageCursor?, limit: Int)
        async throws -> BrewlyAPI.Page<UserSummaryDTO>
    /// `nil` when the member does not exist or a block exists between them and the follower.
    func follow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO?
    func unfollow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO
}

struct PostgresPeopleRepository: PeopleRepository {
    let database: any Database

    private struct ProfileRow: Decodable {
        var id: UUID
        var username: String
        var displayName: String
        var bio: String?
        var avatarUrl: String?
        var location: String?
        var createdAt: Date
        var followerCount: Int
        var followingCount: Int
        var recipeCount: Int
        var isFollowing: Bool
        var followsYou: Bool
    }

    private struct MemberRow: Decodable {
        var id: UUID
        var username: String
        var displayName: String
        var avatarUrl: String?
        var cursorCreatedAt: String?

        var dto: UserSummaryDTO {
            UserSummaryDTO(id: id, username: username, displayName: displayName, avatarURL: avatarUrl)
        }
    }

    func profile(id: UUID, viewerID: UUID) async throws -> UserProfileDTO? {
        guard let row = try await database.sql.raw("""
            SELECT u.id, u.username, u.display_name, u.bio, u.avatar_url, u.location, u.created_at,
                   (SELECT count(*) FROM follows f WHERE f.followed_id = u.id)::int AS follower_count,
                   (SELECT count(*) FROM follows f WHERE f.follower_id = u.id)::int AS following_count,
                   (SELECT count(*) FROM recipes r
                    WHERE r.author_id = u.id
                      AND can_view_content(\(bind: viewerID), r.author_id, r.visibility))::int AS recipe_count,
                   EXISTS (SELECT 1 FROM follows f
                           WHERE f.follower_id = \(bind: viewerID) AND f.followed_id = u.id) AS is_following,
                   EXISTS (SELECT 1 FROM follows f
                           WHERE f.follower_id = u.id AND f.followed_id = \(bind: viewerID)) AS follows_you
            FROM users u
            WHERE u.id = \(bind: id) AND can_view_content(\(bind: viewerID), u.id, 'public')
            """).first()
        else { return nil }
        let profile = try row.decodeSnakeCase(ProfileRow.self)
        return UserProfileDTO(
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName,
            bio: profile.bio,
            avatarURL: profile.avatarUrl,
            location: profile.location,
            createdAt: profile.createdAt,
            followerCount: profile.followerCount,
            followingCount: profile.followingCount,
            recipeCount: profile.recipeCount,
            isFollowing: profile.isFollowing,
            followsYou: profile.followsYou,
            isMe: profile.id == viewerID
        )
    }

    func search(prefix: String, viewerID: UUID, limit: Int) async throws -> [UserSummaryDTO] {
        let pattern = Self.escapedForLike(prefix.lowercased()) + "%"
        return try await database.sql.raw("""
            SELECT u.id, u.username, u.display_name, u.avatar_url
            FROM users u
            WHERE (u.username LIKE \(bind: pattern) OR lower(u.display_name) LIKE \(bind: pattern))
              AND u.id <> \(bind: viewerID)
              AND can_view_content(\(bind: viewerID), u.id, 'public')
            ORDER BY u.username
            LIMIT \(bind: limit)
            """).all().map { try $0.decodeSnakeCase(MemberRow.self).dto }
    }

    func follows(of memberID: UUID, kind: FollowListKind, viewerID: UUID, after cursor: PageCursor?, limit: Int)
        async throws -> BrewlyAPI.Page<UserSummaryDTO> {
        // `memberColumn` is the member whose list is shown, `otherColumn` the people listed.
        let (memberColumn, otherColumn) = switch kind {
        case .followers: ("f.followed_id", "f.follower_id")
        case .following: ("f.follower_id", "f.followed_id")
        }
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let rows = try await database.sql.raw("""
            SELECT u.id, u.username, u.display_name, u.avatar_url,
                   \(unsafeRaw: PageCursor.sqlTimestamp("f.created_at")) AS cursor_created_at
            FROM follows f
            JOIN users u ON u.id = \(unsafeRaw: otherColumn)
            WHERE \(unsafeRaw: memberColumn) = \(bind: memberID)
              AND can_view_content(\(bind: viewerID), u.id, 'public')
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (f.created_at, u.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY f.created_at DESC, u.id DESC
            LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(MemberRow.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.flatMap { row in row.cursorCreatedAt.map { PageCursor(createdAt: $0, id: row.id).encoded() } }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: nextCursor)
    }

    func follow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO? {
        // The main query can't see rows inserted by the CTE, so the new follow is added to the count.
        try await database.sql.raw("""
            WITH target AS (
                SELECT u.id FROM users u
                WHERE u.id = \(bind: memberID) AND can_view_content(\(bind: followerID), u.id, 'public')
            ),
            inserted AS (
                INSERT INTO follows (follower_id, followed_id)
                SELECT \(bind: followerID), id FROM target
                ON CONFLICT DO NOTHING
                RETURNING followed_id
            ),
            notified AS (
                INSERT INTO notifications (recipient_id, actor_id, kind)
                SELECT followed_id, \(bind: followerID), 'follow' FROM inserted
                ON CONFLICT DO NOTHING
            )
            SELECT ((SELECT count(*) FROM follows f WHERE f.followed_id = t.id)
                    + (SELECT count(*) FROM inserted))::int AS follower_count
            FROM target t
            """).first().map {
                FollowStateDTO(isFollowing: true, followerCount: try $0.decode(column: "follower_count", as: Int.self))
            }
    }

    func unfollow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO {
        let row = try await database.sql.raw("""
            WITH deleted AS (
                DELETE FROM follows
                WHERE follower_id = \(bind: followerID) AND followed_id = \(bind: memberID)
                RETURNING followed_id
            ),
            retracted AS (
                DELETE FROM notifications
                WHERE kind = 'follow' AND actor_id = \(bind: followerID) AND recipient_id = \(bind: memberID)
            )
            SELECT ((SELECT count(*) FROM follows f WHERE f.followed_id = \(bind: memberID))
                    - (SELECT count(*) FROM deleted))::int AS follower_count
            """).first()
        return FollowStateDTO(isFollowing: false, followerCount: try row?.decode(column: "follower_count", as: Int.self) ?? 0)
    }

    /// Escapes the `LIKE` wildcards so a search for "a_b" matches literally.
    static func escapedForLike(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
