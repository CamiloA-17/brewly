import BrewlyAPI
import Vapor

/// An error with a stable API code, rendered by `APIErrorMiddleware`.
struct AppError: AbortError {
    let status: HTTPResponseStatus
    let code: String
    let message: String
    var fieldErrors: [APIErrorResponse.FieldError]?

    var reason: String { message }

    static func validation(_ violations: [RuleViolation]) -> AppError {
        AppError(
            status: .unprocessableEntity,
            code: APIErrorCode.validationFailed,
            message: "The request contains invalid fields.",
            fieldErrors: violations.map(APIErrorResponse.FieldError.init)
        )
    }

    /// A single field referencing something that does not exist (e.g. an unknown catalog slug).
    static func unknownReference(field: String) -> AppError {
        AppError(
            status: .unprocessableEntity,
            code: APIErrorCode.validationFailed,
            message: "The request contains invalid fields.",
            fieldErrors: [.init(field: field, code: "not_found", message: "The referenced item does not exist.")]
        )
    }

    static func notFound(_ resource: String) -> AppError {
        AppError(status: .notFound, code: APIErrorCode.notFound, message: "\(resource) not found.")
    }

    static func conflict(code: String, message: String) -> AppError {
        AppError(status: .conflict, code: code, message: message)
    }

    static let unauthorized = AppError(
        status: .unauthorized, code: APIErrorCode.unauthorized, message: "Authentication is required."
    )

    static let invalidCredentials = AppError(
        status: .unauthorized, code: APIErrorCode.invalidCredentials, message: "Invalid email or password."
    )
}
