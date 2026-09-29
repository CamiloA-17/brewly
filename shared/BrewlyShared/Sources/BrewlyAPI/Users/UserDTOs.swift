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

/// The signed-in user's own profile (`GET /me`), including private details.
public struct CurrentUserDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var email: String?
    public var bio: String?
    public var avatarURL: String?
    /// Private.
    public var firstName: String?
    /// Private.
    public var lastName: String?
    /// Private.
    public var birthDate: CalendarDate?
    /// Country of residence (ISO 3166-1 alpha-2).
    public var countryCode: String?
    public var city: String?
    /// The private details are missing: the app shows onboarding before anything else.
    public var needsOnboarding: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        username: String,
        displayName: String,
        email: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        birthDate: CalendarDate? = nil,
        countryCode: String? = nil,
        city: String? = nil,
        needsOnboarding: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.bio = bio
        self.avatarURL = avatarURL
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.countryCode = countryCode
        self.city = city
        self.needsOnboarding = needsOnboarding
        self.createdAt = createdAt
    }
}

/// Body of `PATCH /me`. `nil` clears optional fields.
public struct UpdateProfileRequest: Codable, Sendable, Equatable {
    public var displayName: String
    public var firstName: String
    public var lastName: String
    public var birthDate: CalendarDate?
    public var bio: String?
    public var countryCode: String?
    public var city: String?

    public init(
        displayName: String,
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        bio: String? = nil,
        countryCode: String? = nil,
        city: String? = nil
    ) {
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.bio = bio
        self.countryCode = countryCode
        self.city = city
    }
}

/// Body of `PUT /me/onboarding`: the private details of an account that does not have them yet.
public struct CompleteOnboardingRequest: Codable, Sendable, Equatable {
    public var firstName: String
    public var lastName: String
    public var birthDate: CalendarDate?
    public var acceptedTerms: Bool

    public init(firstName: String, lastName: String, birthDate: CalendarDate?, acceptedTerms: Bool) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.acceptedTerms = acceptedTerms
    }
}

/// Another member's public profile (`GET /users/{id}`), as seen by the viewer.
public struct UserProfileDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var bio: String?
    public var avatarURL: String?
    public var countryCode: String?
    public var city: String?
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
        countryCode: String? = nil,
        city: String? = nil,
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
        self.countryCode = countryCode
        self.city = city
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
