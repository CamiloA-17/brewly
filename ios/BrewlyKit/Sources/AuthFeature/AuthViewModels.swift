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
    var displayName = ""
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
            let user = try await signUp(email: email, password: password, username: username, displayName: displayName)
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
