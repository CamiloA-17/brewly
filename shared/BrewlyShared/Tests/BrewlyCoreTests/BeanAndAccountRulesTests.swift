import BrewlyCore
import Testing

@Suite("BeanRules")
struct BeanRulesTests {
    private let today = CalendarDate(year: 2026, month: 9, day: 25)!

    @Test("A complete bean is valid")
    func validBean() {
        let bean = BeanParameters(
            name: "Geisha Washed", farm: "Finca Las Nubes", altitudeMinM: 1700, altitudeMaxM: 1900,
            roastDate: CalendarDate(year: 2026, month: 9, day: 10), harvestYear: 2025, scaScore: 88.5, weightG: 250
        )
        #expect(BeanRules.validate(bean, today: today).isEmpty)
    }

    @Test("Altitude range, roast date and name are checked")
    func invalidBean() {
        let bean = BeanParameters(
            name: "", altitudeMinM: 2000, altitudeMaxM: 1500,
            roastDate: CalendarDate(year: 2026, month: 10, day: 1), scaScore: 120
        )
        let fields = Set(BeanRules.validate(bean, today: today).map(\.field))
        #expect(fields == ["name", "altitudeMinM", "roastDate", "scaScore"])
    }
}

@Suite("AccountRules")
struct AccountRulesTests {
    @Test("Username format", arguments: [
        ("ana.barista", true), ("leo_2", true), ("ab", false), ("Ana", false), ("ana barista", false), ("café", false),
    ])
    func username(_ value: String, _ isValid: Bool) {
        #expect(AccountRules.isValidUsername(value) == isValid)
    }

    @Test("Email format", arguments: [
        ("ana@example.com", true), ("ana@example", false), ("@example.com", false), ("ana @example.com", false),
    ])
    func email(_ value: String, _ isValid: Bool) {
        #expect(AccountRules.isValidEmail(value) == isValid)
    }

    private let today = CalendarDate(year: 2026, month: 9, day: 25)!

    @Test("Sign-up normalizes email and username before validating")
    func signUp() {
        #expect(AccountRules.validateSignUp(
            email: " Ana@Example.com ", password: "test-password", username: "Ana.Barista",
            firstName: "Ana", lastName: "Rojas", birthDate: CalendarDate(year: 1995, month: 4, day: 12),
            acceptedTerms: true, today: today
        ).isEmpty)
        let fields = Set(AccountRules.validateSignUp(
            email: "nope", password: "short", username: "a", displayName: String(repeating: "x", count: 61),
            firstName: " ", lastName: "", birthDate: nil, acceptedTerms: false, today: today
        ).map(\.field))
        #expect(fields == ["email", "password", "username", "displayName", "firstName", "lastName", "birthDate", "acceptedTerms"])
    }

    @Test("Age is counted in whole years", arguments: [
        (CalendarDate(year: 2013, month: 9, day: 25)!, 13),
        (CalendarDate(year: 2013, month: 9, day: 26)!, 12),
        (CalendarDate(year: 2000, month: 2, day: 29)!, 26),
    ])
    func age(_ birthDate: CalendarDate, _ expected: Int) {
        #expect(AccountRules.age(birthDate: birthDate, on: today) == expected)
    }

    @Test("Birth date must be real, past and at least 13 years ago")
    func birthDate() {
        func kind(_ date: CalendarDate?) -> RuleViolation.Kind? {
            AccountRules.validateOnboarding(
                firstName: "Ana", lastName: "Rojas", birthDate: date, acceptedTerms: true, today: today
            ).first { $0.field == "birthDate" }?.kind
        }
        #expect(kind(CalendarDate(year: 2013, month: 9, day: 25)) == nil)
        #expect(kind(CalendarDate(year: 2013, month: 9, day: 26)) == .tooYoung(minimumAge: 13))
        #expect(kind(CalendarDate(year: 2027, month: 1, day: 1)) == .inFuture)
        #expect(kind(CalendarDate(year: 1899, month: 12, day: 31)) == .invalidFormat)
        #expect(kind(nil) == .required)
    }

    @Test("Profile checks country code and city")
    func profile() {
        let valid = AccountRules.validateProfile(
            displayName: "Ana", firstName: "Ana", lastName: "Rojas",
            birthDate: CalendarDate(year: 1995, month: 4, day: 12), bio: nil, countryCode: "DE", city: nil, today: today
        )
        #expect(valid.isEmpty)
        let fields = Set(AccountRules.validateProfile(
            displayName: "Ana", firstName: "Ana", lastName: "Rojas",
            birthDate: CalendarDate(year: 1995, month: 4, day: 12), bio: nil, countryCode: "co",
            city: String(repeating: "x", count: 81), today: today
        ).map(\.field))
        #expect(fields == ["countryCode", "city"])
    }

    @Test("Default display name joins first and last name")
    func defaultDisplayName() {
        #expect(AccountRules.defaultDisplayName(firstName: " Ana ", lastName: "Rojas") == "Ana Rojas")
    }
}
