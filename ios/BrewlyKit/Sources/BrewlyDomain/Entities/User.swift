import Foundation

/// The signed-in user's own profile, including private details.
public struct UserProfile: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var email: String?
    public var bio: String?
    public var avatarURL: URL?
    /// Private.
    public var firstName: String?
    /// Private.
    public var lastName: String?
    /// Private.
    public var birthDate: CalendarDate?
    /// Country of residence (ISO 3166-1 alpha-2).
    public var countryCode: String?
    public var city: String?
    /// The private details are missing: onboarding comes before anything else.
    public var needsOnboarding: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        username: String,
        displayName: String,
        email: String? = nil,
        bio: String? = nil,
        avatarURL: URL? = nil,
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

/// An email sign-up. The public display name defaults to "First Last".
public struct NewAccount: Hashable, Sendable {
    public var email: String
    public var password: String
    public var username: String
    public var firstName: String
    public var lastName: String
    public var birthDate: CalendarDate?
    public var acceptedTerms: Bool

    public init(
        email: String,
        password: String,
        username: String,
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        acceptedTerms: Bool
    ) {
        self.email = email
        self.password = password
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.acceptedTerms = acceptedTerms
    }
}

/// Private details asked in onboarding.
public struct PersonalDetails: Hashable, Sendable {
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

/// Editable profile fields. `nil` clears optional ones.
public struct ProfileChanges: Hashable, Sendable {
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
    public var countryCode: String?
    public var city: String?
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
        countryCode: String? = nil,
        city: String? = nil,
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
