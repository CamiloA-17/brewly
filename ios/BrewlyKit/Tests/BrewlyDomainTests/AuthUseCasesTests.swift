import BrewlyDomain
import Foundation
import Testing

@Suite("Sign-up and onboarding")
struct AuthUseCasesTests {
    private let today = CalendarDate(year: 2026, month: 9, day: 27)!

    @Test("Sign-up normalizes the account before sending it")
    func signUpNormalizes() async throws {
        let auth = RecordingAuthRepository()
        _ = try await SignUpUseCase(auth: auth)(NewAccount(
            email: " Ana@Example.com ", password: "test-password", username: "Ana.Barista",
            firstName: " Ana ", lastName: "Rojas ", birthDate: CalendarDate(year: 1995, month: 4, day: 12),
            acceptedTerms: true
        ), today: today)

        let sent = try #require(await auth.signedUp)
        #expect(sent.email == "ana@example.com")
        #expect(sent.username == "ana.barista")
        #expect(sent.firstName == "Ana")
        #expect(sent.lastName == "Rojas")
    }

    @Test("Sign-up is rejected locally for members under 13 and without accepted terms")
    func signUpRejectsMinors() async {
        let auth = RecordingAuthRepository()
        let violations = await validationErrors {
            _ = try await SignUpUseCase(auth: auth)(NewAccount(
                email: "kid@example.com", password: "test-password", username: "kid",
                firstName: "Kid", lastName: "Demo", birthDate: CalendarDate(year: 2014, month: 1, day: 1),
                acceptedTerms: false
            ), today: today)
        }
        #expect(violations.contains(RuleViolation(field: "birthDate", kind: .tooYoung(minimumAge: 13))))
        #expect(violations.contains(RuleViolation(field: "acceptedTerms", kind: .required)))
        #expect(await auth.signedUp == nil)
    }

    @Test("Onboarding requires a birth date")
    func onboardingRequiresBirthDate() async {
        let violations = await validationErrors {
            _ = try await CompleteOnboardingUseCase(profile: UnreachableProfileRepository())(
                PersonalDetails(firstName: "Ana", lastName: "Rojas", birthDate: nil, acceptedTerms: true),
                today: today
            )
        }
        #expect(violations == [RuleViolation(field: "birthDate", kind: .required)])
    }

    private func validationErrors(_ operation: () async throws -> Void) async -> [RuleViolation] {
        do {
            try await operation()
            Issue.record("Expected a validation error")
        } catch let DomainError.validation(violations) {
            return violations
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        return []
    }
}

private actor RecordingAuthRepository: AuthRepository {
    private(set) var signedUp: NewAccount?

    func signIn(email: String, password: String) async throws -> UserProfile {
        throw DomainError.invalidCredentials
    }

    func signUp(_ account: NewAccount) async throws -> UserProfile {
        signedUp = account
        return UserProfile(id: UUID(), username: account.username, displayName: account.firstName, createdAt: Date())
    }

    func signOut() async {}

    func hasStoredSession() async -> Bool { false }
}

private struct UnreachableProfileRepository: ProfileRepository {
    func currentUser() async throws -> UserProfile { throw DomainError.unexpected("unreachable") }
    func updateProfile(_ changes: ProfileChanges) async throws -> UserProfile { throw DomainError.unexpected("unreachable") }
    func completeOnboarding(_ details: PersonalDetails) async throws -> UserProfile { throw DomainError.unexpected("unreachable") }
    func updateAvatar(imageData: Data) async throws -> UserProfile { throw DomainError.unexpected("unreachable") }
    func removeAvatar() async throws -> UserProfile { throw DomainError.unexpected("unreachable") }
    func deleteAccount() async throws { throw DomainError.unexpected("unreachable") }
}
