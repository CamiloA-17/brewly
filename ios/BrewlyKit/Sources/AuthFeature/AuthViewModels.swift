import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class SignInViewModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?

    private let signIn: SignInUseCase

    init(signIn: SignInUseCase) {
        self.signIn = signIn
    }

    func submit() async -> UserProfile? {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let user = try await signIn(email: email, password: password)
            violations = []
            errorMessage = nil
            return user
        } catch let DomainError.validation(violations) {
            self.violations = violations
            errorMessage = nil
        } catch {
            violations = []
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}

@MainActor
@Observable
final class SignUpViewModel {
    var email = ""
    var password = ""
    var username = ""
    var firstName = ""
    var lastName = ""
    var birthDate: CalendarDate?
    var acceptedTerms = false
    private(set) var isSubmitting = false
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?

    private let signUp: SignUpUseCase

    init(signUp: SignUpUseCase) {
        self.signUp = signUp
    }

    func submit() async -> UserProfile? {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let user = try await signUp(NewAccount(
                email: email, password: password, username: username, firstName: firstName, lastName: lastName,
                birthDate: birthDate, acceptedTerms: acceptedTerms
            ))
            violations = []
            errorMessage = nil
            return user
        } catch let DomainError.validation(violations) {
            self.violations = violations
            errorMessage = nil
        } catch {
            violations = []
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}

/// Private details of accounts created without them (older accounts, Sign in with Apple).
@MainActor
@Observable
final class OnboardingViewModel {
    var firstName: String
    var lastName: String
    var birthDate: CalendarDate?
    var acceptedTerms = false
    private(set) var isSubmitting = false
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?

    private let completeOnboarding: CompleteOnboardingUseCase

    init(user: UserProfile, completeOnboarding: CompleteOnboardingUseCase) {
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        birthDate = user.birthDate
        self.completeOnboarding = completeOnboarding
    }

    func submit() async -> UserProfile? {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let user = try await completeOnboarding(PersonalDetails(
                firstName: firstName, lastName: lastName, birthDate: birthDate, acceptedTerms: acceptedTerms
            ))
            violations = []
            errorMessage = nil
            return user
        } catch let DomainError.validation(violations) {
            self.violations = violations
            errorMessage = nil
        } catch {
            violations = []
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}

@MainActor
@Observable
final class FederatedSignInViewModel {
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    private let signIn: FederatedSignInUseCase
    init(signIn: FederatedSignInUseCase) { self.signIn = signIn }

    func submit(_ provider: IdentityProvider) async -> UserProfile? {
        guard !isSubmitting else { return nil }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            return try await signIn(provider)
        } catch DomainError.signInCancelled {
            return nil
        } catch is CancellationError {
            return nil
        } catch DomainError.conflict(code: "email_taken") {
            errorMessage = String(localized: "An account with this email already exists. Sign in using its original method.", bundle: .module)
        } catch DomainError.invalidCredentials {
            errorMessage = String(localized: "We couldn't verify this sign-in. Please try again.", bundle: .module)
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}
