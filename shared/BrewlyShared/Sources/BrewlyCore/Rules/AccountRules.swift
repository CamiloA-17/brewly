/// Validation rules for accounts and profiles. Limits mirror the `users` table.
public enum AccountRules {
    public static let usernameLengthRange: ClosedRange<Int> = 3...30
    public static let passwordLengthRange: ClosedRange<Int> = 8...128
    public static let displayNameMaxLength = 60
    public static let bioMaxLength = 300
    public static let locationMaxLength = 80

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

    public static func validateSignUp(
        email: String,
        password: String,
        username: String,
        displayName: String
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
        check.requireText(displayName, field: "displayName", maxLength: displayNameMaxLength)
        return check.violations
    }

    public static func validateProfile(displayName: String, bio: String?, location: String?) -> [RuleViolation] {
        var check = ViolationCollector()
        check.requireText(displayName, field: "displayName", maxLength: displayNameMaxLength)
        check.optionalText(bio, field: "bio", maxLength: bioMaxLength)
        check.optionalText(location, field: "location", maxLength: locationMaxLength)
        return check.violations
    }
}
