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
