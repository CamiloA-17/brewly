/// Validation rules for accounts and profiles. Limits mirror the `users` table.
public enum AccountRules {
    public static let usernameLengthRange: ClosedRange<Int> = 3...30
    public static let passwordLengthRange: ClosedRange<Int> = 8...128
    public static let displayNameMaxLength = 60
    public static let nameMaxLength = 60
    public static let bioMaxLength = 300
    public static let cityMaxLength = 80
    /// Members must be at least this old (App Store and COPPA).
    public static let minimumAge = 13
    public static let earliestBirthDate = CalendarDate(year: 1900, month: 1, day: 1)!

    /// Lowercase letters, digits, `_` and `.`; 3 to 30 characters.
    public static func isValidUsername(_ username: String) -> Bool {
        usernameLengthRange.contains(username.count) && username.unicodeScalars.allSatisfy { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "_" || scalar == "."
        }
    }

    /// A pragmatic check: one `@`, a non-empty local part and a dotted domain.
    public static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// Lowercases and trims an email or username before storing or comparing it.
    public static func normalize(_ value: String) -> String {
        value.trimmingWhitespace.lowercased()
    }

    /// The public name shown when none is chosen: "First Last".
    public static func defaultDisplayName(firstName: String, lastName: String) -> String {
        let name = "\(firstName.trimmingWhitespace) \(lastName.trimmingWhitespace)".trimmingWhitespace
        return String(name.prefix(displayNameMaxLength))
    }

    /// Whole years between `birthDate` and `today`.
    public static func age(birthDate: CalendarDate, on today: CalendarDate) -> Int {
        let hadBirthday = (today.month, today.day) >= (birthDate.month, birthDate.day)
        return today.year - birthDate.year - (hadBirthday ? 0 : 1)
    }

    /// Two uppercase ASCII letters (ISO 3166-1 alpha-2), e.g. `"CO"`.
    public static func isValidCountryCode(_ code: String) -> Bool {
        code.unicodeScalars.count == 2 && code.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) }
    }

    public static func validateSignUp(
        email: String,
        password: String,
        username: String,
        displayName: String? = nil,
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        acceptedTerms: Bool,
        today: CalendarDate = .today()
    ) -> [RuleViolation] {
        var check = ViolationCollector()
        let email = normalize(email)
        if email.isEmpty {
            check.add("email", .required)
        } else if !isValidEmail(email) {
            check.add("email", .invalidFormat)
        }
        if !passwordLengthRange.contains(password.count) {
            check.add("password", .outOfRange(
                min: Double(passwordLengthRange.lowerBound),
                max: Double(passwordLengthRange.upperBound)
            ))
        }
        let username = normalize(username)
        if username.isEmpty {
            check.add("username", .required)
        } else if !isValidUsername(username) {
            check.add("username", .invalidFormat)
        }
        check.optionalText(displayName, field: "displayName", maxLength: displayNameMaxLength)
        check.personalDetails(firstName: firstName, lastName: lastName, birthDate: birthDate, today: today)
        if !acceptedTerms {
            check.add("acceptedTerms", .required)
        }
        return check.violations
    }

    /// Onboarding of accounts that do not have their private details yet.
    public static func validateOnboarding(
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        acceptedTerms: Bool,
        today: CalendarDate = .today()
    ) -> [RuleViolation] {
        var check = ViolationCollector()
        check.personalDetails(firstName: firstName, lastName: lastName, birthDate: birthDate, today: today)
        if !acceptedTerms {
            check.add("acceptedTerms", .required)
        }
        return check.violations
    }

    public static func validateProfile(
        displayName: String,
        firstName: String,
        lastName: String,
        birthDate: CalendarDate?,
        bio: String?,
        countryCode: String?,
        city: String?,
        today: CalendarDate = .today()
    ) -> [RuleViolation] {
        var check = ViolationCollector()
        check.requireText(displayName, field: "displayName", maxLength: displayNameMaxLength)
        check.personalDetails(firstName: firstName, lastName: lastName, birthDate: birthDate, today: today)
        check.optionalText(bio, field: "bio", maxLength: bioMaxLength)
        if let countryCode, !countryCode.isEmpty, !isValidCountryCode(countryCode) {
            check.add("countryCode", .invalidFormat)
        }
        check.optionalText(city, field: "city", maxLength: cityMaxLength)
        return check.violations
    }
}

private extension ViolationCollector {
    mutating func personalDetails(firstName: String, lastName: String, birthDate: CalendarDate?, today: CalendarDate) {
        requireText(firstName, field: "firstName", maxLength: AccountRules.nameMaxLength)
        requireText(lastName, field: "lastName", maxLength: AccountRules.nameMaxLength)
        guard let birthDate else {
            add("birthDate", .required)
            return
        }
        if birthDate > today {
            add("birthDate", .inFuture)
        } else if birthDate < AccountRules.earliestBirthDate {
            add("birthDate", .invalidFormat)
        } else if AccountRules.age(birthDate: birthDate, on: today) < AccountRules.minimumAge {
            add("birthDate", .tooYoung(minimumAge: AccountRules.minimumAge))
        }
    }
}
