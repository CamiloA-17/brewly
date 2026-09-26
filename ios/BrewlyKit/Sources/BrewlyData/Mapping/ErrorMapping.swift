import BrewlyAPI
import BrewlyDomain
import BrewlyNetworking
import Foundation

extension DomainError {
    /// Translates transport and HTTP errors into domain errors.
    static func from(_ error: any Error) -> DomainError {
        if let domainError = error as? DomainError { return domainError }
        guard let apiError = error as? APIError else {
            return .unexpected(String(describing: error))
        }
        switch apiError {
        case .transport:
            return .offline
        case .unauthorized:
            return .unauthorized
        case let .decoding(message):
            return .unexpected(message)
        case let .http(status, body):
            switch (status, body?.code) {
            case (401, APIErrorCode.invalidCredentials):
                return .invalidCredentials
            case (401, _):
                return .unauthorized
            case (404, _):
                return .notFound
            case (409, let code):
                return .conflict(code: code ?? APIErrorCode.conflict)
            case (422, _):
                let violations = (body?.fieldErrors ?? []).map {
                    RuleViolation(field: $0.field, kind: Self.kind(forCode: $0.code))
                }
                return .validation(violations)
            default:
                return .unexpected(body?.message ?? "HTTP \(status)")
            }
        }
    }

    /// Server field errors carry codes, not bounds; map them to the closest local kind.
    private static func kind(forCode code: String) -> RuleViolation.Kind {
        switch code {
        case "required": .required
        case "too_long": .tooLong(max: 0)
        case "in_future": .inFuture
        case "not_allowed": .notAllowed
        case "too_young": .tooYoung(minimumAge: AccountRules.minimumAge)
        default: .invalidFormat
        }
    }
}

/// Runs an API call and converts its errors to `DomainError`.
/// Runs on the caller's isolation so actors can pass closures that touch their state.
func mappingErrors<T>(
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws -> T
) async throws -> T {
    do {
        return try await operation()
    } catch {
        throw DomainError.from(error)
    }
}
