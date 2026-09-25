import Foundation

/// The signed-in user's own profile.
public struct UserProfile: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var email: String?
    public var bio: String?
    public var avatarURL: URL?
    public var location: String?
    public var createdAt: Date

    public init(
        id: UUID,
        username: String,
        displayName: String,
        email: String? = nil,
        bio: String? = nil,
        avatarURL: URL? = nil,
        location: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.createdAt = createdAt
    }
}

/// Public identity of another member (e.g. a recipe author).
public struct UserSummary: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var avatarURL: URL?

    public init(id: UUID, username: String, displayName: String, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

/// Another member's public profile, as seen by the signed-in user.
public struct MemberProfile: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var bio: String?
    public var avatarURL: URL?
    public var location: String?
    public var createdAt: Date
    public var followerCount: Int
    public var followingCount: Int
    /// Recipes of this member that the signed-in user can see.
    public var recipeCount: Int
    public var isFollowing: Bool
    public var followsYou: Bool
    /// The profile belongs to the signed-in user.
    public var isMe: Bool

    public init(
        id: UUID,
        username: String,
        displayName: String,
        bio: String? = nil,
        avatarURL: URL? = nil,
        location: String? = nil,
        createdAt: Date = Date(),
        followerCount: Int = 0,
        followingCount: Int = 0,
        recipeCount: Int = 0,
        isFollowing: Bool = false,
        followsYou: Bool = false,
        isMe: Bool = false
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.createdAt = createdAt
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.recipeCount = recipeCount
        self.isFollowing = isFollowing
        self.followsYou = followsYou
        self.isMe = isMe
    }

    public var summary: UserSummary {
        UserSummary(id: id, username: username, displayName: displayName, avatarURL: avatarURL)
    }
}

/// Whether the signed-in user follows a member, and the member's follower count.
public struct FollowState: Hashable, Sendable {
    public var isFollowing: Bool
    public var followerCount: Int

    public init(isFollowing: Bool, followerCount: Int) {
        self.isFollowing = isFollowing
        self.followerCount = followerCount
    }
}
