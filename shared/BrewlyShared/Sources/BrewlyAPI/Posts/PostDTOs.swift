import BrewlyCore
import Foundation

/// An uploaded image. `url` is relative to the API base URL (`/v1/media/{id}`).
public struct MediaDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var url: String
    public var width: Int
    public var height: Int

    public init(id: UUID, url: String, width: Int, height: Int) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
    }
}

/// A post in a feed or on its own, as seen by the viewer.
public struct PostDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var author: UserSummaryDTO
    public var kind: PostKind
    public var body: String?
    /// The shared recipe; `nil` for other kinds or when the viewer can't see it.
    public var recipe: RecipeSummaryDTO?
    /// The shared bean; `nil` for other kinds or when the viewer can't see it.
    public var bean: BeanSummaryDTO?
    public var media: [MediaDTO]
    public var visibility: Visibility
    public var likeCount: Int
    public var commentCount: Int
    /// Whether the viewer liked the post.
    public var isLiked: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        author: UserSummaryDTO,
        kind: PostKind,
        body: String? = nil,
        recipe: RecipeSummaryDTO? = nil,
        bean: BeanSummaryDTO? = nil,
        media: [MediaDTO] = [],
        visibility: Visibility = .public,
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date
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
}

/// Body of `POST /posts`. Upload photos first with `POST /media` and send their ids in order.
public struct CreatePostRequest: Codable, Sendable, Equatable {
    public var body: String?
    public var recipeId: UUID?
    public var beanId: UUID?
    public var mediaIds: [UUID]
    public var visibility: Visibility

    public init(
        body: String? = nil,
        recipeId: UUID? = nil,
        beanId: UUID? = nil,
        mediaIds: [UUID] = [],
        visibility: Visibility = .public
    ) {
        self.body = body
        self.recipeId = recipeId
        self.beanId = beanId
        self.mediaIds = mediaIds
        self.visibility = visibility
    }
}

/// Response of `PUT` and `DELETE /posts/{id}/like`.
public struct LikeStateDTO: Codable, Sendable, Equatable {
    public var isLiked: Bool
    public var likeCount: Int

    public init(isLiked: Bool, likeCount: Int) {
        self.isLiked = isLiked
        self.likeCount = likeCount
    }
}

public struct CommentDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var postId: UUID
    /// The top-level comment this one replies to.
    public var parentId: UUID?
    public var author: UserSummaryDTO
    public var body: String
    /// The viewer wrote the comment or the post, so they can delete it.
    public var canDelete: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        postId: UUID,
        parentId: UUID? = nil,
        author: UserSummaryDTO,
        body: String,
        canDelete: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.postId = postId
        self.parentId = parentId
        self.author = author
        self.body = body
        self.canDelete = canDelete
        self.createdAt = createdAt
    }
}

/// Body of `POST /posts/{id}/comments`. Replies to a reply are attached to its top-level comment.
public struct CreateCommentRequest: Codable, Sendable, Equatable {
    public var body: String
    public var parentId: UUID?

    public init(body: String, parentId: UUID? = nil) {
        self.body = body
        self.parentId = parentId
    }
}
