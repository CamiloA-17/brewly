import BrewlyDomain
import Foundation
import Supabase

struct SupabaseSocialRepository: SocialRepository {
    let client: SupabaseClient

    private struct FeedParams: Encodable {
        let p_limit: Int
        let p_before_created_at: String?
        let p_before_id: UUID?
    }

    func homeFeed(after cursor: FeedCursor?, limit: Int) async throws -> [Post] {
        try await client
            .rpc("home_feed", params: FeedParams(
                p_limit: limit,
                p_before_created_at: cursor.map { PostgresDate.format($0.createdAt) },
                p_before_id: cursor?.id
            ))
            .select(Select.post)
            .execute()
            .value
    }

    func exploreFeed(offset: Int, limit: Int, kind: PostKind?) async throws -> [Post] {
        struct Params: Encodable {
            let p_limit: Int
            let p_offset: Int
            let p_kind: PostKind?
        }
        return try await client
            .rpc("explore_feed", params: Params(p_limit: limit, p_offset: offset, p_kind: kind))
            .select(Select.post)
            .execute()
            .value
    }

    func posts(authorID: UUID, after cursor: FeedCursor?, limit: Int) async throws -> [Post] {
        var query = client.from("posts").select(Select.post).eq("author_id", value: authorID)
        if let cursor {
            query = query.lt("created_at", value: PostgresDate.format(cursor.createdAt))
        }
        return try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func savedPosts() async throws -> [Post] {
        let me = try client.requireUserID()
        struct SavedRow: Decodable { let post: Post? }
        let rows: [SavedRow] = try await client.from("saved_posts")
            .select("post:posts(\(Select.post))")
            .eq("user_id", value: me)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap(\.post)
    }

    func publish(_ request: PublishRequest) async throws -> Post {
        let me = try client.requireUserID()

        struct Params: Encodable {
            let p_kind: PostKind
            let p_content_id: UUID?
            let p_caption: String?
            let p_visibility: Visibility
            let p_comments_enabled: Bool
        }
        struct Created: Decodable { let id: UUID }

        // 1. Crea el post (y amplía la visibilidad del contenido) en una transacción.
        let created: Created = try await client
            .rpc("publish_post", params: Params(
                p_kind: request.kind,
                p_content_id: request.contentID,
                p_caption: request.caption,
                p_visibility: request.visibility,
                p_comments_enabled: request.commentsEnabled
            ))
            .execute()
            .value

        // 2. Sube las imágenes y registra su metadata. Si algo falla se borra el post.
        do {
            struct MediaRow: Encodable {
                let post_id: UUID
                let storage_path: String
                let media_type: MediaType
                let position: Int
            }
            var rows: [MediaRow] = []
            for (index, data) in request.images.enumerated() {
                let path = "\(me.uuidString.lowercased())/\(created.id.uuidString.lowercased())/\(index).jpg"
                try await client.storage.from("post-media").upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
                rows.append(MediaRow(post_id: created.id, storage_path: path, media_type: .image, position: index))
            }
            if !rows.isEmpty {
                try await client.from("post_media").insert(rows).execute()
            }
        } catch {
            try? await deletePost(id: created.id)
            throw error
        }

        // 3. Devuelve el post completo, listo para insertarse en el feed.
        return try await client.from("posts")
            .select(Select.post)
            .eq("id", value: created.id)
            .single()
            .execute()
            .value
    }

    func deletePost(id: UUID) async throws {
        try await client.from("posts").delete().eq("id", value: id).execute()
    }

    func setLiked(_ liked: Bool, postID: UUID) async throws {
        let me = try client.requireUserID()
        if liked {
            struct Row: Encodable { let user_id: UUID; let post_id: UUID }
            try await client.from("likes")
                .upsert(Row(user_id: me, post_id: postID), onConflict: "user_id,post_id", ignoreDuplicates: true)
                .execute()
        } else {
            try await client.from("likes").delete()
                .eq("user_id", value: me)
                .eq("post_id", value: postID)
                .execute()
        }
    }

    func setSaved(_ saved: Bool, postID: UUID) async throws {
        let me = try client.requireUserID()
        if saved {
            struct Row: Encodable { let user_id: UUID; let post_id: UUID }
            try await client.from("saved_posts")
                .upsert(Row(user_id: me, post_id: postID), onConflict: "user_id,post_id", ignoreDuplicates: true)
                .execute()
        } else {
            try await client.from("saved_posts").delete()
                .eq("user_id", value: me)
                .eq("post_id", value: postID)
                .execute()
        }
    }

    func comments(postID: UUID) async throws -> [Comment] {
        try await client.from("comments")
            .select(Select.comment)
            .eq("post_id", value: postID)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> Comment {
        let me = try client.requireUserID()
        struct Row: Encodable {
            let post_id: UUID
            let author_id: UUID
            let parent_id: UUID?
            let body: String
        }
        return try await client.from("comments")
            .insert(Row(post_id: postID, author_id: me, parent_id: parentID, body: body))
            .select(Select.comment)
            .single()
            .execute()
            .value
    }

    func deleteComment(id: UUID) async throws {
        try await client.from("comments").delete().eq("id", value: id).execute()
    }

    func mediaURL(for media: PostMedia) async throws -> URL {
        try await client.storage.from("post-media")
            .createSignedURL(path: media.storagePath, expiresIn: 60 * 60)
    }
}

struct SupabaseRelationshipRepository: RelationshipRepository {
    let client: SupabaseClient

    private struct FollowRow: Codable {
        let follower_id: UUID
        let following_id: UUID
        var status: FollowStatus?
    }

    func follow(userID: UUID) async throws -> FollowStatus {
        let me = try client.requireUserID()
        // El servidor decide si queda `pending` (cuenta privada) o `accepted`.
        let row: FollowRow = try await client.from("follows")
            .insert(FollowRow(follower_id: me, following_id: userID))
            .select()
            .single()
            .execute()
            .value
        return row.status ?? .pending
    }

    func unfollow(userID: UUID) async throws {
        let me = try client.requireUserID()
        try await client.from("follows").delete()
            .eq("follower_id", value: me)
            .eq("following_id", value: userID)
            .execute()
    }

    func pendingRequests() async throws -> [Profile] {
        let me = try client.requireUserID()
        struct Row: Decodable { let follower: Profile }
        let rows: [Row] = try await client.from("follows")
            .select("follower:profiles!follows_follower_id_fkey(*)")
            .eq("following_id", value: me)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map(\.follower)
    }

    func respond(toRequestFrom userID: UUID, accept: Bool) async throws {
        let me = try client.requireUserID()
        let query = client.from("follows")
        if accept {
            struct Update: Encodable { let status = "accepted" }
            try await query.update(Update())
                .eq("follower_id", value: userID)
                .eq("following_id", value: me)
                .execute()
        } else {
            try await query.delete()
                .eq("follower_id", value: userID)
                .eq("following_id", value: me)
                .execute()
        }
    }

    func followers(of userID: UUID) async throws -> [Profile] {
        struct Row: Decodable { let follower: Profile }
        let rows: [Row] = try await client.from("follows")
            .select("follower:profiles!follows_follower_id_fkey(*)")
            .eq("following_id", value: userID)
            .eq("status", value: "accepted")
            .execute()
            .value
        return rows.map(\.follower)
    }

    func following(of userID: UUID) async throws -> [Profile] {
        struct Row: Decodable { let following: Profile }
        let rows: [Row] = try await client.from("follows")
            .select("following:profiles!follows_following_id_fkey(*)")
            .eq("follower_id", value: userID)
            .eq("status", value: "accepted")
            .execute()
            .value
        return rows.map(\.following)
    }

    func block(userID: UUID) async throws {
        let me = try client.requireUserID()
        struct Row: Encodable { let blocker_id: UUID; let blocked_id: UUID }
        try await client.from("blocks")
            .upsert(Row(blocker_id: me, blocked_id: userID), onConflict: "blocker_id,blocked_id", ignoreDuplicates: true)
            .execute()
    }

    func unblock(userID: UUID) async throws {
        let me = try client.requireUserID()
        try await client.from("blocks").delete()
            .eq("blocker_id", value: me)
            .eq("blocked_id", value: userID)
            .execute()
    }
}

struct SupabaseNotificationRepository: NotificationRepository {
    let client: SupabaseClient

    func notifications(limit: Int) async throws -> [AppNotification] {
        try await client.from("notifications")
            .select(Select.notification)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func unreadCount() async throws -> Int {
        let response = try await client.from("notifications")
            .select("id", head: true, count: .exact)
            .is("read_at", value: nil)
            .execute()
        return response.count ?? 0
    }

    func markAllAsRead() async throws {
        struct Update: Encodable { let read_at: String }
        try await client.from("notifications")
            .update(Update(read_at: PostgresDate.format(.now)))
            .is("read_at", value: nil)
            .execute()
    }

    func registerPushToken(_ token: String) async throws {
        struct Params: Encodable { let p_token: String }
        try await client.rpc("register_push_token", params: Params(p_token: token)).execute()
    }

    func liveNotifications() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                guard let me = client.auth.currentUser?.id else {
                    continuation.finish()
                    return
                }
                let channel = client.channel("notifications:\(me.uuidString.lowercased())")
                let inserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: "recipient_id=eq.\(me.uuidString.lowercased())"
                )
                await channel.subscribe()
                for await _ in inserts {
                    continuation.yield()
                }
                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
