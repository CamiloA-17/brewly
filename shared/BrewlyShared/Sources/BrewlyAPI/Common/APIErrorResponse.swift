import BrewlyCore

/// Body of every non-2xx response.
public struct APIErrorResponse: Codable, Sendable, Equatable {
    public struct FieldError: Codable, Sendable, Equatable {
        /// JSON key of the offending request property.
        public var field: String
        public var code: String
        public var message: String

        public init(field: String, code: String, message: String) {
            self.field = field
            self.code = code
            self.message = message
        }

        public init(_ violation: RuleViolation) {
            self.init(field: violation.field, code: violation.code, message: violation.defaultMessage)
        }
    }

    /// Stable machine-readable code, e.g. `"validation_failed"` or `"not_found"`.
    public var code: String
    /// Human-readable English message.
    public var message: String
    public var fieldErrors: [FieldError]?

    public init(code: String, message: String, fieldErrors: [FieldError]? = nil) {
        self.code = code
        self.message = message
        self.fieldErrors = fieldErrors
    }
}

/// Error codes returned in `APIErrorResponse.code`.
public enum APIErrorCode {
    public static let validationFailed = "validation_failed"
    public static let unauthorized = "unauthorized"
    public static let invalidCredentials = "invalid_credentials"
    public static let forbidden = "forbidden"
    public static let notFound = "not_found"
    public static let conflict = "conflict"
    public static let usernameTaken = "username_taken"
    public static let emailTaken = "email_taken"
    public static let beanInUse = "bean_in_use"
    public static let cannotFollowSelf = "cannot_follow_self"
    public static let badRequest = "bad_request"
    public static let internalError = "internal_error"
}
