import Foundation

/// Public identity embedded in other resources (recipe author, post author…).
public struct UserSummaryDTO: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var avatarURL: String?

    public init(id: UUID, username: String, displayName: String, avatarURL: String? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

/// The signed-in user's own profile (`GET /me`).
public struct CurrentUserDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var email: String?
    public var bio: String?
    public var avatarURL: String?
    public var location: String?
    public var createdAt: Date

    public init(
        id: UUID,
        username: String,
        displayName: String,
        email: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil,
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

/// Body of `PATCH /me`. `nil` clears optional fields.
public struct UpdateProfileRequest: Codable, Sendable, Equatable {
    public var displayName: String
    public var bio: String?
    public var location: String?

    public init(displayName: String, bio: String? = nil, location: String? = nil) {
        self.displayName = displayName
        self.bio = bio
        self.location = location
    }
}

/// Another member's public profile (`GET /users/{id}`), as seen by the viewer.
public struct UserProfileDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var bio: String?
    public var avatarURL: String?
    public var location: String?
    public var createdAt: Date
    public var followerCount: Int
    public var followingCount: Int
    /// Recipes of this member that the viewer can see.
    public var recipeCount: Int
    /// The viewer follows this member.
    public var isFollowing: Bool
    /// This member follows the viewer.
    public var followsYou: Bool
    /// The profile belongs to the viewer.
    public var isMe: Bool

    public init(
        id: UUID,
        username: String,
        displayName: String,
        bio: String? = nil,
        avatarURL: String? = nil,
        location: String? = nil,
        createdAt: Date,
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

    public var summary: UserSummaryDTO {
        UserSummaryDTO(id: id, username: username, displayName: displayName, avatarURL: avatarURL)
    }
}

/// Response of `PUT` and `DELETE /users/{id}/follow`.
public struct FollowStateDTO: Codable, Sendable, Equatable {
    public var isFollowing: Bool
    /// Followers of the member after the change.
    public var followerCount: Int

    public init(isFollowing: Bool, followerCount: Int) {
        self.isFollowing = isFollowing
        self.followerCount = followerCount
    }
}

/// Body of `PUT /me/avatar`. Upload the image first with `POST /media`.
public struct UpdateAvatarRequest: Codable, Sendable, Equatable {
    public var mediaId: UUID

    public init(mediaId: UUID) {
        self.mediaId = mediaId
    }
}
