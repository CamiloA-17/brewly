import Foundation

public struct RegisterRequest: Codable, Sendable, Equatable {
    public var email: String
    public var password: String
    public var username: String
    /// Public name; defaults to "First Last" when omitted.
    public var displayName: String?
    public var firstName: String
    public var lastName: String
    /// Private. Members must be at least `AccountRules.minimumAge` years old.
    public var birthDate: CalendarDate?
    public var acceptedTerms: Bool

    public init(
        email: String,
        password: String,
        username: String,
        displayName: String? = nil,
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        acceptedTerms: Bool
    ) {
        self.email = email
        self.password = password
        self.username = username
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.acceptedTerms = acceptedTerms
    }
}

public struct LoginRequest: Codable, Sendable, Equatable {
    public var email: String
    public var password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Body of `POST /auth/refresh` and `POST /auth/logout`.
public struct RefreshTokenRequest: Codable, Sendable, Equatable {
    public var refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Returned by register, login and refresh.
public struct AuthResponse: Codable, Sendable, Equatable {
    /// Short-lived JWT sent as `Authorization: Bearer <token>`.
    public var accessToken: String
    public var accessTokenExpiresAt: Date
    /// Opaque single-use token exchanged for a new pair at `POST /auth/refresh`.
    public var refreshToken: String
    public var refreshTokenExpiresAt: Date
    public var user: CurrentUserDTO

    public init(
        accessToken: String,
        accessTokenExpiresAt: Date,
        refreshToken: String,
        refreshTokenExpiresAt: Date,
        user: CurrentUserDTO
    ) {
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshToken = refreshToken
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.user = user
    }
}
