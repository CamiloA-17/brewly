import Foundation

public struct SignInUseCase: Sendable {
    private let auth: any AuthRepository

    public init(auth: any AuthRepository) {
        self.auth = auth
    }

    public func callAsFunction(email: String, password: String) async throws -> UserProfile {
        var violations: [RuleViolation] = []
        if email.trimmingWhitespace.isEmpty { violations.append(RuleViolation(field: "email", kind: .required)) }
        if password.isEmpty { violations.append(RuleViolation(field: "password", kind: .required)) }
        guard violations.isEmpty else { throw DomainError.validation(violations) }
        return try await auth.signIn(email: AccountRules.normalize(email), password: password)
    }
}

public struct SignUpUseCase: Sendable {
    private let auth: any AuthRepository

    public init(auth: any AuthRepository) {
        self.auth = auth
    }

    public func callAsFunction(_ account: NewAccount, today: CalendarDate = .today()) async throws -> UserProfile {
        let violations = AccountRules.validateSignUp(
            email: account.email, password: account.password, username: account.username,
            firstName: account.firstName, lastName: account.lastName, birthDate: account.birthDate,
            acceptedTerms: account.acceptedTerms, today: today
        )
        guard violations.isEmpty else { throw DomainError.validation(violations) }
        var normalized = account
        normalized.email = AccountRules.normalize(account.email)
        normalized.username = AccountRules.normalize(account.username)
        normalized.firstName = account.firstName.trimmingWhitespace
        normalized.lastName = account.lastName.trimmingWhitespace
        return try await auth.signUp(normalized)
    }
}

/// Completes the private details of accounts created without them.
public struct CompleteOnboardingUseCase: Sendable {
    private let profile: any ProfileRepository

    public init(profile: any ProfileRepository) {
        self.profile = profile
    }

    public func callAsFunction(_ details: PersonalDetails, today: CalendarDate = .today()) async throws -> UserProfile {
        let violations = AccountRules.validateOnboarding(
            firstName: details.firstName, lastName: details.lastName, birthDate: details.birthDate,
            acceptedTerms: details.acceptedTerms, today: today
        )
        guard violations.isEmpty else { throw DomainError.validation(violations) }
        var trimmed = details
        trimmed.firstName = details.firstName.trimmingWhitespace
        trimmed.lastName = details.lastName.trimmingWhitespace
        return try await profile.completeOnboarding(trimmed)
    }
}
