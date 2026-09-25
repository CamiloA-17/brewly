import BrewlyAPI
import PostgresNIO
import Vapor

/// Converts every thrown error into an `APIErrorResponse` JSON body.
struct APIErrorMiddleware: AsyncMiddleware {
    let environment: Environment

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            return response(for: error, request: request)
        }
    }

    private func response(for error: any Error, request: Request) -> Response {
        let status: HTTPResponseStatus
        let body: APIErrorResponse

        switch error {
        case let appError as AppError:
            status = appError.status
            body = APIErrorResponse(code: appError.code, message: appError.message, fieldErrors: appError.fieldErrors)
        case let psqlError as PSQLError where psqlError.isUniqueViolation:
            status = .conflict
            body = APIErrorResponse(code: APIErrorCode.conflict, message: "The resource already exists.")
        case let psqlError as PSQLError where psqlError.isForeignKeyViolation:
            status = .conflict
            body = APIErrorResponse(code: APIErrorCode.conflict, message: "The resource is referenced by other data.")
        case let psqlError as PSQLError where psqlError.isCheckViolation:
            status = .unprocessableEntity
            body = APIErrorResponse(code: APIErrorCode.validationFailed, message: "The request contains invalid values.")
        case let abort as any AbortError:
            status = abort.status
            body = APIErrorResponse(code: Self.code(for: abort.status), message: abort.reason)
        default:
            status = .internalServerError
            let message = environment.isRelease ? "Something went wrong." : String(describing: error)
            body = APIErrorResponse(code: APIErrorCode.internalError, message: message)
        }

        if status.code >= 500 {
            request.logger.report(error: error)
        } else {
            request.logger.debug("Request failed with \(status.code): \(body.code)")
        }

        do {
            return try Response.json(body, status: status)
        } catch {
            return Response(status: .internalServerError)
        }
    }

    private static func code(for status: HTTPResponseStatus) -> String {
        switch status {
        case .unauthorized: APIErrorCode.unauthorized
        case .forbidden: APIErrorCode.forbidden
        case .notFound: APIErrorCode.notFound
        case .conflict: APIErrorCode.conflict
        case .unprocessableEntity: APIErrorCode.validationFailed
        case .badRequest: APIErrorCode.badRequest
        default: status.code >= 500 ? APIErrorCode.internalError : APIErrorCode.badRequest
        }
    }
}
