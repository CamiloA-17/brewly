import Foundation

/// Something another member did that concerns the signed-in user.
public struct AppNotification: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var kind: NotificationKind
    public var actor: UserSummary
    public var postID: UUID?
    public var postExcerpt: String?
    public var commentID: UUID?
    public var commentExcerpt: String?
    /// The saved recipe, or the new remix.
    public var recipeID: UUID?
    public var recipeTitle: String?
    public var isRead: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        kind: NotificationKind,
        actor: UserSummary,
        postID: UUID? = nil,
        postExcerpt: String? = nil,
        commentID: UUID? = nil,
        commentExcerpt: String? = nil,
        recipeID: UUID? = nil,
        recipeTitle: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.postID = postID
        self.postExcerpt = postExcerpt
        self.commentID = commentID
        self.commentExcerpt = commentExcerpt
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
