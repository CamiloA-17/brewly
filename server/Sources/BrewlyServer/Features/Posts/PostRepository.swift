import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

/// Which posts a list returns. Every list only includes posts the viewer can see.
enum PostListScope: Sendable {
    /// The viewer's posts and those of the people they follow.
    case feed
    /// Public posts of the community.
    case explore
    /// One member's posts.
    case authoredBy(UUID)
}

protocol PostRepository: Sendable {
    func list(scope: PostListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<PostDTO>
    /// The post if `viewerID` is allowed to see it.
    func find(id: UUID, viewerID: UUID) async throws -> PostDTO?
    /// Creates the post and attaches the author's uploaded images in order.
    func create(authorID: UUID, kind: PostKind, _ request: CreatePostRequest) async throws -> PostDTO
    /// Deletes the post and its images; `false` when it does not exist or is not the author's.
    func delete(id: UUID, authorID: UUID) async throws -> Bool
    /// `nil` when the post does not exist or the user can't see it.
    func like(postID: UUID, userID: UUID) async throws -> LikeStateDTO?
    func unlike(postID: UUID, userID: UUID) async throws -> LikeStateDTO

    /// Comments of a visible post, oldest first; `nil` when the post is not visible.
    func comments(postID: UUID, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<CommentDTO>?
    /// `nil` when the post is not visible to the author of the comment.
    func addComment(postID: UUID, authorID: UUID, body: String, parentID: UUID?) async throws -> CommentDTO?
    /// Deletes a comment written by the user or on the user's post, with its replies.
    func deleteComment(id: UUID, userID: UUID) async throws -> Bool
}

/// A reply names a comment that does not belong to the post.
struct UnknownParentCommentError: Error {}

/// Media ids that are not the author's unused uploads.
struct UnavailableMediaError: Error {}

struct PostgresPostRepository: PostRepository {
    let database: any Database

    // MARK: - Rows

    private struct PostRow: Decodable {
        var id: UUID
        var kind: String
        var body: String?
        var visibility: String
        var createdAt: Date
        var cursorCreatedAt: String
        var authorId: UUID
        var authorUsername: String
        var authorDisplayName: String
        var authorAvatarUrl: String?
        var likeCount: Int
        var commentCount: Int
        var isLiked: Bool
        var mediaIds: [UUID]
        var mediaWidths: [Int]
        var mediaHeights: [Int]
        var rId: UUID?
        var rTitle: String?
        var rMethodSlug: String?
        var rDoseG: Double?
        var rRatio: Double?
        var rGrindSize: String?
        var rWaterTempC: Double?
        var rTotalTimeS: Int?
        var rRating: Int?
        var rVisibility: String?
        var rCreatedAt: Date?
        var rBeanName: String?
        var bId: UUID?
        var bName: String?
        var bRoaster: String?
        var bCountryCode: String?
        var bFarm: String?
        var bProcessingMethodSlug: String?
        var bRoastLevel: String?
        var bVarietalSlugs: [String]?

        var dto: PostDTO {
            let author = UserSummaryDTO(
                id: authorId, username: authorUsername, displayName: authorDisplayName, avatarURL: authorAvatarUrl
            )
            var recipe: RecipeSummaryDTO?
            if let rId, let rTitle, let rMethodSlug, let rDoseG, let rRatio, let rCreatedAt, let rBeanName {
                recipe = RecipeSummaryDTO(
                    id: rId,
                    author: author,
                    beanName: rBeanName,
                    methodSlug: rMethodSlug,
                    title: rTitle,
                    doseG: rDoseG,
                    ratio: rRatio,
                    grindSize: rGrindSize.flatMap(GrindSize.init(rawValue:)) ?? .medium,
                    waterTempC: rWaterTempC,
                    totalTimeS: rTotalTimeS,
                    rating: rRating,
                    visibility: rVisibility.flatMap(Visibility.init(rawValue:)) ?? .private,
                    createdAt: rCreatedAt
                )
            }
            var bean: BeanSummaryDTO?
            if let bId, let bName {
                bean = BeanSummaryDTO(
                    id: bId,
                    name: bName,
                    roaster: bRoaster,
                    countryCode: bCountryCode,
                    farm: bFarm,
                    processingMethodSlug: bProcessingMethodSlug,
                    varietalSlugs: bVarietalSlugs ?? [],
                    roastLevel: bRoastLevel.flatMap(RoastLevel.init(rawValue:))
                )
            }
            let media = zip(mediaIds, zip(mediaWidths, mediaHeights)).map { id, size in
                MediaDTO(id: id, url: PostgresMediaRepository.url(for: id), width: size.0, height: size.1)
            }
            return PostDTO(
                id: id,
                author: author,
                kind: PostKind(rawValue: kind) ?? .text,
                body: body,
                recipe: recipe,
                bean: bean,
                media: media,
                visibility: Visibility(rawValue: visibility) ?? .private,
                likeCount: likeCount,
                commentCount: commentCount,
                isLiked: isLiked,
                createdAt: createdAt
            )
        }
    }

    private struct CommentRow: Decodable {
        var id: UUID
        var postId: UUID
        var parentId: UUID?
        var body: String
        var createdAt: Date
        var cursorCreatedAt: String
        var canDelete: Bool
        var authorId: UUID
        var authorUsername: String
        var authorDisplayName: String
        var authorAvatarUrl: String?

        var dto: CommentDTO {
            CommentDTO(
                id: id,
                postId: postId,
                parentId: parentId,
                author: UserSummaryDTO(
                    id: authorId, username: authorUsername, displayName: authorDisplayName, avatarURL: authorAvatarUrl
                ),
                body: body,
                canDelete: canDelete,
                createdAt: createdAt
            )
        }
    }

    // MARK: - SQL fragments

    /// Needs a `viewer` CTE with the viewer's id. Shared recipes and beans are only included when
    /// the viewer can see them.
    private static let postSelect = """
        SELECT p.id, p.kind, p.body, p.visibility::text AS visibility, p.created_at,
               \(PageCursor.sqlTimestamp("p.created_at")) AS cursor_created_at,
               u.id AS author_id, u.username AS author_username, u.display_name AS author_display_name,
               u.avatar_url AS author_avatar_url,
               (SELECT count(*) FROM post_likes l WHERE l.post_id = p.id)::int AS like_count,
               (SELECT count(*) FROM comments c WHERE c.post_id = p.id)::int AS comment_count,
               EXISTS (SELECT 1 FROM post_likes l WHERE l.post_id = p.id AND l.user_id = v.viewer_id) AS is_liked,
               coalesce((SELECT array_agg(pm.media_id ORDER BY pm.position)
                         FROM post_media pm WHERE pm.post_id = p.id), '{}') AS media_ids,
               coalesce((SELECT array_agg(m.width::int8 ORDER BY pm.position)
                         FROM post_media pm JOIN media m ON m.id = pm.media_id WHERE pm.post_id = p.id), '{}') AS media_widths,
               coalesce((SELECT array_agg(m.height::int8 ORDER BY pm.position)
                         FROM post_media pm JOIN media m ON m.id = pm.media_id WHERE pm.post_id = p.id), '{}') AS media_heights,
               r.id AS r_id, r.title AS r_title, r.method_slug AS r_method_slug, r.dose_g::float8 AS r_dose_g,
               r.ratio::float8 AS r_ratio, r.grind_size::text AS r_grind_size,
               r.water_temp_c::float8 AS r_water_temp_c, r.total_time_s AS r_total_time_s, r.rating AS r_rating,
               r.visibility::text AS r_visibility, r.created_at AS r_created_at, rb.name AS r_bean_name,
               b.id AS b_id, b.name AS b_name, b.roaster AS b_roaster, b.country_code::text AS b_country_code,
               b.farm AS b_farm, b.processing_method_slug AS b_processing_method_slug,
               b.roast_level::text AS b_roast_level,
               CASE WHEN b.id IS NOT NULL THEN
                   coalesce((SELECT array_agg(bv.varietal_slug ORDER BY bv.varietal_slug)
                             FROM bean_varietals bv WHERE bv.bean_id = b.id), '{}')
               END AS b_varietal_slugs
        FROM posts p
        CROSS JOIN viewer v
        JOIN users u ON u.id = p.author_id
        LEFT JOIN recipes r ON r.id = p.recipe_id AND can_view_content(v.viewer_id, r.author_id, r.visibility)
        LEFT JOIN coffee_beans rb ON rb.id = r.bean_id
        LEFT JOIN coffee_beans b ON b.id = p.bean_id AND can_view_content(v.viewer_id, b.owner_id, b.visibility)
        """

    private static let commentSelect = """
        SELECT c.id, c.post_id, c.parent_id, c.body, c.created_at,
               \(PageCursor.sqlTimestamp("c.created_at")) AS cursor_created_at,
               (c.author_id = v.viewer_id OR p.author_id = v.viewer_id) AS can_delete,
               u.id AS author_id, u.username AS author_username, u.display_name AS author_display_name,
               u.avatar_url AS author_avatar_url
        FROM comments c
        CROSS JOIN viewer v
        JOIN posts p ON p.id = c.post_id
        JOIN users u ON u.id = c.author_id
        """

    // MARK: - Posts

    func list(scope: PostListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<PostDTO> {
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let filter: SQLQueryString = switch scope {
        case .feed:
            """
            (p.author_id = v.viewer_id OR EXISTS (
                SELECT 1 FROM follows f WHERE f.follower_id = v.viewer_id AND f.followed_id = p.author_id))
            """
        case .explore:
            "p.visibility = 'public'"
        case let .authoredBy(authorID):
            "p.author_id = \(bind: authorID)"
        }
        let rows = try await database.sql.raw("""
            WITH viewer AS (SELECT \(bind: viewerID)::uuid AS viewer_id)
            \(unsafeRaw: Self.postSelect)
            WHERE \(filter)
              AND can_view_content(v.viewer_id, p.author_id, p.visibility)
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (p.created_at, p.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY p.created_at DESC, p.id DESC
            LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(PostRow.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorCreatedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: nextCursor)
    }

    func find(id: UUID, viewerID: UUID) async throws -> PostDTO? {
        try await Self.find(id: id, viewerID: viewerID, sql: database.sql)
    }

    private static func find(id: UUID, viewerID: UUID, sql: any SQLDatabase) async throws -> PostDTO? {
        try await sql.raw("""
            WITH viewer AS (SELECT \(bind: viewerID)::uuid AS viewer_id)
            \(unsafeRaw: Self.postSelect)
            WHERE p.id = \(bind: id) AND can_view_content(v.viewer_id, p.author_id, p.visibility)
            """).first().map { try $0.decodeSnakeCase(PostRow.self).dto }
    }

    func create(authorID: UUID, kind: PostKind, _ request: CreatePostRequest) async throws -> PostDTO {
        try await database.transaction { tx in
            let sql = tx.sql
            guard let row = try await sql.raw("""
                INSERT INTO posts (author_id, kind, body, recipe_id, bean_id, visibility)
                VALUES (\(bind: authorID), \(bind: kind.rawValue), \(bind: request.body), \(bind: request.recipeId),
                        \(bind: request.beanId), \(bind: request.visibility.rawValue))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: APIErrorCode.internalError, message: "Post was not created.") }
            let id = try row.decode(column: "id", as: UUID.self)

            if !request.mediaIds.isEmpty {
                // Only the author's uploads that are not an avatar can be attached.
                let attached = try await sql.raw("""
                    INSERT INTO post_media (post_id, position, media_id)
                    SELECT \(bind: id), x.position::smallint, m.id
                    FROM unnest(\(bind: request.mediaIds)::uuid[]) WITH ORDINALITY AS x(media_id, position)
                    JOIN media m ON m.id = x.media_id AND m.owner_id = \(bind: authorID)
                    WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.avatar_media_id = m.id)
                    RETURNING media_id
                    """).all()
                guard attached.count == request.mediaIds.count else { throw UnavailableMediaError() }
            }
            guard let created = try await Self.find(id: id, viewerID: authorID, sql: sql) else {
                throw AppError.notFound("Post")
            }
            return created
        }
    }

    func delete(id: UUID, authorID: UUID) async throws -> Bool {
        try await database.transaction { tx in
            let sql = tx.sql
            guard try await sql.raw("""
                SELECT 1 FROM posts WHERE id = \(bind: id) AND author_id = \(bind: authorID) FOR UPDATE
                """).first() != nil
            else { return false }
            // The images belong only to this post.
            try await sql.raw("""
                DELETE FROM media WHERE id IN (SELECT media_id FROM post_media WHERE post_id = \(bind: id))
                """).run()
            try await sql.raw("DELETE FROM posts WHERE id = \(bind: id)").run()
            return true
        }
    }

    func like(postID: UUID, userID: UUID) async throws -> LikeStateDTO? {
        // The main query can't see rows inserted by the CTE, so the new like is added to the count.
        try await database.sql.raw("""
            WITH target AS (
                SELECT p.id FROM posts p
                WHERE p.id = \(bind: postID) AND can_view_content(\(bind: userID), p.author_id, p.visibility)
            ),
            inserted AS (
                INSERT INTO post_likes (post_id, user_id)
                SELECT id, \(bind: userID) FROM target
                ON CONFLICT DO NOTHING
                RETURNING post_id
            )
            SELECT ((SELECT count(*) FROM post_likes l WHERE l.post_id = t.id)
                    + (SELECT count(*) FROM inserted))::int AS like_count
            FROM target t
            """).first().map { LikeStateDTO(isLiked: true, likeCount: try $0.decode(column: "like_count", as: Int.self)) }
    }

    func unlike(postID: UUID, userID: UUID) async throws -> LikeStateDTO {
        let row = try await database.sql.raw("""
            WITH deleted AS (
                DELETE FROM post_likes WHERE post_id = \(bind: postID) AND user_id = \(bind: userID)
                RETURNING post_id
            )
            SELECT ((SELECT count(*) FROM post_likes l WHERE l.post_id = \(bind: postID))
                    - (SELECT count(*) FROM deleted))::int AS like_count
            """).first()
        return LikeStateDTO(isLiked: false, likeCount: try row?.decode(column: "like_count", as: Int.self) ?? 0)
    }

    // MARK: - Comments

    func comments(postID: UUID, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<CommentDTO>? {
        guard try await isVisible(postID: postID, viewerID: viewerID) else { return nil }
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        // Oldest first, so the cursor moves forward in time. Comments by blocked members are hidden.
        let rows = try await database.sql.raw("""
            WITH viewer AS (SELECT \(bind: viewerID)::uuid AS viewer_id)
            \(unsafeRaw: Self.commentSelect)
            WHERE c.post_id = \(bind: postID)
              AND can_view_content(v.viewer_id, c.author_id, 'public')
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (c.created_at, c.id) > (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY c.created_at, c.id
            LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(CommentRow.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorCreatedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: nextCursor)
    }

    func addComment(postID: UUID, authorID: UUID, body: String, parentID: UUID?) async throws -> CommentDTO? {
        try await database.transaction { tx in
            let sql = tx.sql
            guard try await Self.isVisible(postID: postID, viewerID: authorID, sql: sql) else { return nil }
            // Replies to a reply are attached to its top-level comment, so threads are one level deep.
            var rootID: UUID?
            if let parentID {
                guard let row = try await sql.raw("""
                    SELECT coalesce(parent_id, id) AS root_id FROM comments
                    WHERE id = \(bind: parentID) AND post_id = \(bind: postID)
                    """).first()
                else { throw UnknownParentCommentError() }
                rootID = try row.decode(column: "root_id", as: UUID.self)
            }
            guard let inserted = try await sql.raw("""
                INSERT INTO comments (post_id, author_id, parent_id, body)
                VALUES (\(bind: postID), \(bind: authorID), \(bind: rootID), \(bind: body))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: APIErrorCode.internalError, message: "Comment was not created.") }
            let id = try inserted.decode(column: "id", as: UUID.self)
            return try await sql.raw("""
                WITH viewer AS (SELECT \(bind: authorID)::uuid AS viewer_id)
                \(unsafeRaw: Self.commentSelect)
                WHERE c.id = \(bind: id)
                """).first().map { try $0.decodeSnakeCase(CommentRow.self).dto }
        }
    }

    func deleteComment(id: UUID, userID: UUID) async throws -> Bool {
        try await database.sql.raw("""
            DELETE FROM comments c USING posts p
            WHERE c.id = \(bind: id) AND p.id = c.post_id
              AND (c.author_id = \(bind: userID) OR p.author_id = \(bind: userID))
            RETURNING c.id
            """).first() != nil
    }

    private func isVisible(postID: UUID, viewerID: UUID) async throws -> Bool {
        try await Self.isVisible(postID: postID, viewerID: viewerID, sql: database.sql)
    }

    private static func isVisible(postID: UUID, viewerID: UUID, sql: any SQLDatabase) async throws -> Bool {
        try await sql.raw("""
            SELECT 1 FROM posts p
            WHERE p.id = \(bind: postID) AND can_view_content(\(bind: viewerID), p.author_id, p.visibility)
            """).first() != nil
    }
}
