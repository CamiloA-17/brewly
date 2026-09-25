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

    @Test("Sign-up normalizes email and username before validating")
    func signUp() {
        #expect(AccountRules.validateSignUp(
            email: " Ana@Example.com ", password: "test-password", username: "Ana.Barista", displayName: "Ana"
        ).isEmpty)
        let fields = Set(AccountRules.validateSignUp(
            email: "nope", password: "short", username: "a", displayName: " "
        ).map(\.field))
        #expect(fields == ["email", "password", "username", "displayName"])
    }
}
