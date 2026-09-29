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
