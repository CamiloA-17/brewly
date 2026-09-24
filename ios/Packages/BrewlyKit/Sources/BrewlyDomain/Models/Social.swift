import Foundation

public struct PostMedia: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var storagePath: String
    public var mediaType: MediaType
    public var position: Int
    public var width: Int?
    public var height: Int?
    public var blurhash: String?

    enum CodingKeys: String, CodingKey {
        case id, position, width, height, blurhash
        case storagePath = "storage_path"
        case mediaType = "media_type"
    }

    public init(
        id: UUID = UUID(),
        storagePath: String,
        mediaType: MediaType = .image,
        position: Int = 0,
        width: Int? = nil,
        height: Int? = nil,
        blurhash: String? = nil
    ) {
        self.id = id
        self.storagePath = storagePath
        self.mediaType = mediaType
        self.position = position
        self.width = width
        self.height = height
        self.blurhash = blurhash
    }
}

public struct Post: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var authorID: UUID
    public var kind: PostKind
    public var caption: String?
    public var visibility: Visibility
    public var commentsEnabled: Bool
    public var likeCount: Int
    public var commentCount: Int
    public var createdAt: Date

    // Relaciones y campos calculados embebidos.
    public var author: Profile?
    public var media: [PostMedia]
    public var recipe: Recipe?
    public var brew: Brew?
    public var bean: CoffeeBean?
    public var likedByMe: Bool
    public var savedByMe: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, caption, visibility, author, media, recipe, brew, bean
        case authorID = "author_id"
        case commentsEnabled = "comments_enabled"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case likedByMe = "liked_by_me"
        case savedByMe = "saved_by_me"
    }

    public init(
        id: UUID = UUID(),
        authorID: UUID,
        kind: PostKind,
        caption: String? = nil,
        visibility: Visibility = .public,
        commentsEnabled: Bool = true,
        likeCount: Int = 0,
        commentCount: Int = 0,
        createdAt: Date = .now,
        author: Profile? = nil,
        media: [PostMedia] = [],
        recipe: Recipe? = nil,
        brew: Brew? = nil,
        bean: CoffeeBean? = nil,
        likedByMe: Bool = false,
        savedByMe: Bool = false
    ) {
        self.id = id
        self.authorID = authorID
        self.kind = kind
        self.caption = caption
        self.visibility = visibility
        self.commentsEnabled = commentsEnabled
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.author = author
        self.media = media
        self.recipe = recipe
        self.brew = brew
        self.bean = bean
        self.likedByMe = likedByMe
        self.savedByMe = savedByMe
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        authorID = try c.decode(UUID.self, forKey: .authorID)
        kind = try c.decode(PostKind.self, forKey: .kind)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        visibility = try c.decode(Visibility.self, forKey: .visibility)
        commentsEnabled = try c.decodeIfPresent(Bool.self, forKey: .commentsEnabled) ?? true
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        author = try c.decodeIfPresent(Profile.self, forKey: .author)
        media = (try c.decodeIfPresent([PostMedia].self, forKey: .media) ?? [])
            .sorted { $0.position < $1.position }
        recipe = try c.decodeIfPresent(Recipe.self, forKey: .recipe)
        brew = try c.decodeIfPresent(Brew.self, forKey: .brew)
        bean = try c.decodeIfPresent(CoffeeBean.self, forKey: .bean)
        likedByMe = try c.decodeIfPresent(Bool.self, forKey: .likedByMe) ?? false
        savedByMe = try c.decodeIfPresent(Bool.self, forKey: .savedByMe) ?? false
    }

    /// Cursor para pedir la siguiente página del feed.
    public var cursor: FeedCursor { FeedCursor(createdAt: createdAt, id: id) }
}

public struct FeedCursor: Hashable, Sendable {
    public var createdAt: Date
    public var id: UUID

    public init(createdAt: Date, id: UUID) {
        self.createdAt = createdAt
        self.id = id
    }
}

public struct Comment: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var postID: UUID
    public var authorID: UUID
    public var parentID: UUID?
    public var body: String
    public var createdAt: Date
    public var editedAt: Date?
    public var author: Profile?

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case postID = "post_id"
        case authorID = "author_id"
        case parentID = "parent_id"
        case createdAt = "created_at"
        case editedAt = "edited_at"
    }

    public init(
        id: UUID = UUID(),
        postID: UUID,
        authorID: UUID,
        parentID: UUID? = nil,
        body: String,
        createdAt: Date = .now,
        editedAt: Date? = nil,
        author: Profile? = nil
    ) {
        self.id = id
        self.postID = postID
        self.authorID = authorID
        self.parentID = parentID
        self.body = body
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.author = author
    }
}

public struct AppNotification: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var type: NotificationType
    public var actor: Profile?
    public var postID: UUID?
    public var commentID: UUID?
    public var recipeID: UUID?
    public var readAt: Date?
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, actor
        case postID = "post_id"
        case commentID = "comment_id"
        case recipeID = "recipe_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    public init(
        id: UUID = UUID(),
        type: NotificationType,
        actor: Profile? = nil,
        postID: UUID? = nil,
        commentID: UUID? = nil,
        recipeID: UUID? = nil,
        readAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.actor = actor
        self.postID = postID
        self.commentID = commentID
        self.recipeID = recipeID
        self.readAt = readAt
        self.createdAt = createdAt
    }

    public var isRead: Bool { readAt != nil }

    public var message: String {
        let name = "@" + (actor?.username ?? "alguien")
        return switch type {
        case .follow: "\(name) comenzó a seguirte"
        case .followRequest: "\(name) quiere seguirte"
        case .followAccepted: "\(name) aceptó tu solicitud"
        case .like: "A \(name) le gustó tu publicación"
        case .comment: "\(name) comentó tu publicación"
        case .reply: "\(name) respondió a tu comentario"
        case .fork: "\(name) guardó una copia de tu receta"
        }
    }
}
