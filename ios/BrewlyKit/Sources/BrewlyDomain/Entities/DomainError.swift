/// Errors surfaced to the presentation layer.
public enum DomainError: Error, Hashable, Sendable {
    /// One or more fields are invalid.
    case validation([RuleViolation])
    case notFound
    /// The operation conflicts with existing data (e.g. `"bean_in_use"`, `"username_taken"`).
    case conflict(code: String)
    case invalidCredentials
    /// The session expired or is invalid; the user must sign in again.
    case unauthorized
    /// No connection or the server could not be reached.
    case offline
    /// Anything else, with a diagnostic message.
    case unexpected(String)
}
