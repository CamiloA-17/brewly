import Foundation

public struct Profile: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var username: String
    public var displayName: String?
    public var bio: String?
    public var avatarPath: String?
    public var role: UserRole
    public var location: String?
    public var website: String?
    public var isPrivate: Bool
    public var followersCount: Int
    public var followingCount: Int
    public var postsCount: Int
    public var createdAt: Date
    /// Relación del usuario actual con este perfil (campo calculado en el servidor).
    public var viewerFollowStatus: FollowStatus?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, role, location, website
        case displayName = "display_name"
        case avatarPath = "avatar_path"
        case isPrivate = "is_private"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case postsCount = "posts_count"
        case createdAt = "created_at"
        case viewerFollowStatus = "viewer_follow_status"
    }

    public init(
        id: UUID,
        username: String,
        displayName: String? = nil,
        bio: String? = nil,
        avatarPath: String? = nil,
        role: UserRole = .enthusiast,
        location: String? = nil,
        website: String? = nil,
        isPrivate: Bool = false,
        followersCount: Int = 0,
        followingCount: Int = 0,
        postsCount: Int = 0,
        createdAt: Date = .now,
        viewerFollowStatus: FollowStatus? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarPath = avatarPath
        self.role = role
        self.location = location
        self.website = website
        self.isPrivate = isPrivate
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.postsCount = postsCount
        self.createdAt = createdAt
        self.viewerFollowStatus = viewerFollowStatus
    }

    public var nameToDisplay: String { displayName?.isEmpty == false ? displayName! : username }
}

/// Campos editables del perfil propio.
public struct ProfileUpdate: Encodable, Sendable {
    public var username: String
    public var displayName: String?
    public var bio: String?
    public var role: UserRole
    public var location: String?
    public var website: String?
    public var isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case username, bio, role, location, website
        case displayName = "display_name"
        case isPrivate = "is_private"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(username, forKey: .username)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(bio, forKey: .bio)
        try c.encode(role, forKey: .role)
        try c.encode(location, forKey: .location)
        try c.encode(website, forKey: .website)
        try c.encode(isPrivate, forKey: .isPrivate)
    }

    public init(from profile: Profile) {
        username = profile.username
        displayName = profile.displayName
        bio = profile.bio
        role = profile.role
        location = profile.location
        website = profile.website
        isPrivate = profile.isPrivate
    }
}
