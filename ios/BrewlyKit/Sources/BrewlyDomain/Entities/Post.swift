import Foundation

/// An uploaded image. `url` may be relative to the API base URL.
public struct MediaItem: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var url: URL
    public var width: Int
    public var height: Int

    public init(id: UUID, url: URL, width: Int, height: Int) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
    }

    /// Width divided by height, for laying out the image before it loads.
    public var aspectRatio: Double {
        height > 0 ? Double(width) / Double(height) : 1
    }
}

/// A post: text, up to four photos and optionally one of the author's recipes or beans.
public struct Post: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var author: UserSummary
    public var kind: PostKind
    public var body: String?
    /// The shared recipe, when the signed-in user can see it.
    public var recipe: RecipeSummary?
    /// The shared bean, when the signed-in user can see it.
    public var bean: BeanSummary?
    public var media: [MediaItem]
    public var visibility: Visibility
    public var likeCount: Int
    public var commentCount: Int
    public var isLiked: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        author: UserSummary,
        kind: PostKind = .text,
        body: String? = nil,
        recipe: RecipeSummary? = nil,
        bean: BeanSummary? = nil,
        media: [MediaItem] = [],
        visibility: Visibility = .public,
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.kind = kind
        self.body = body
        self.recipe = recipe
        self.bean = bean
        self.media = media
        self.visibility = visibility
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }

    /// Applies a like or unlike, e.g. before the server confirms it.
    public mutating func apply(_ like: LikeState) {
        isLiked = like.isLiked
        likeCount = like.likeCount
    }
}

/// Whether the signed-in user liked a post, and how many people did.
public struct LikeState: Hashable, Sendable {
    public var isLiked: Bool
    public var likeCount: Int

    public init(isLiked: Bool, likeCount: Int) {
        self.isLiked = isLiked
        self.likeCount = likeCount
    }
}

public struct Comment: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var postID: UUID
    /// The top-level comment this one replies to.
    public var parentID: UUID?
    public var author: UserSummary
    public var body: String
    /// The signed-in user wrote the comment or the post.
    public var canDelete: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        postID: UUID,
        parentID: UUID? = nil,
        author: UserSummary,
        body: String,
        canDelete: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.author = author
        self.body = body
        self.canDelete = canDelete
        self.createdAt = createdAt
    }
}

/// A post being written. Photos are the picked image files; the data layer resizes them.
public struct PostDraft: Hashable, Sendable {
    public var body = ""
    public var recipeID: UUID?
    public var beanID: UUID?
    public var photos: [Data] = []
    public var visibility: Visibility = .public

    public init() {}

    /// Every broken rule of the draft; empty when it can be published.
    public var violations: [RuleViolation] {
        PostRules.validatePost(
            body: body, sharesRecipe: recipeID != nil, sharesBean: beanID != nil, photoCount: photos.count
        )
    }
}
