import BrewlyAPI
import Vapor

/// The signed-in user's notifications.
struct NotificationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notifications = routes.grouped("me", "notifications")
        notifications.get(use: list)
        notifications.get("unread-count", use: unreadCount)
        notifications.post("read", use: markAllRead)
    }

    /// `GET /me/notifications?cursor=&limit=`: newest first.
    @Sendable
    func list(req: Request) async throws -> Response {
        let page = try await repository(req).list(
            recipientID: try req.userID,
            after: try PageCursor.decodeParameter(req.query[String.self, at: "cursor"]),
            limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func unreadCount(req: Request) async throws -> Response {
        try .json(UnreadCountDTO(count: try await repository(req).unreadCount(recipientID: try req.userID)))
    }

    /// `POST /me/notifications/read`: marks every notification as read.
    @Sendable
    func markAllRead(req: Request) async throws -> HTTPStatus {
        try await repository(req).markAllRead(recipientID: try req.userID)
        return .noContent
    }

    private func repository(_ req: Request) -> any NotificationRepository {
        PostgresNotificationRepository(database: req.db)
    }
}
