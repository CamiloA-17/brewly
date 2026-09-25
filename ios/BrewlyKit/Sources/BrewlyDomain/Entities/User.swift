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
