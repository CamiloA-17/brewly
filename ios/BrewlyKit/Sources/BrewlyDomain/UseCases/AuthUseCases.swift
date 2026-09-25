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

    public func callAsFunction(email: String, password: String, username: String, displayName: String) async throws -> UserProfile {
        let violations = AccountRules.validateSignUp(
            email: email, password: password, username: username, displayName: displayName
        )
        guard violations.isEmpty else { throw DomainError.validation(violations) }
        return try await auth.signUp(
            email: AccountRules.normalize(email),
            password: password,
            username: AccountRules.normalize(username),
            displayName: displayName.trimmingWhitespace
        )
    }
}
