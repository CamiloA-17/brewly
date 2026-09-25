import BrewlyCore
import Foundation

/// Something another member did that concerns the user.
public struct NotificationDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var kind: NotificationKind
    public var actor: UserSummaryDTO
    public var postId: UUID?
    /// The beginning of the post's text, when it has any.
    public var postExcerpt: String?
    public var commentId: UUID?
    /// The beginning of the comment.
    public var commentExcerpt: String?
    public var recipeId: UUID?
    public var recipeTitle: String?
    public var isRead: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        kind: NotificationKind,
        actor: UserSummaryDTO,
        postId: UUID? = nil,
        postExcerpt: String? = nil,
        commentId: UUID? = nil,
        commentExcerpt: String? = nil,
        recipeId: UUID? = nil,
        recipeTitle: String? = nil,
        isRead: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.postId = postId
        self.postExcerpt = postExcerpt
        self.commentId = commentId
        self.commentExcerpt = commentExcerpt
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

/// Response of `GET /me/notifications/unread-count`.
public struct UnreadCountDTO: Codable, Sendable, Equatable {
    public var count: Int

    public init(count: Int) {
        self.count = count
    }
}
