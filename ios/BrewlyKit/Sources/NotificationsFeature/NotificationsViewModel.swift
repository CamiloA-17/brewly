import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

public struct NotificationsDependencies: Sendable {
    public var notifications: any NotificationRepository

    public init(notifications: any NotificationRepository) {
        self.notifications = notifications
    }
}

@MainActor
@Observable
final class NotificationsViewModel {
    let paginator: Paginator<AppNotification>
    private let notifications: any NotificationRepository

    init(dependencies: NotificationsDependencies) {
        let notifications = dependencies.notifications
        self.notifications = notifications
        paginator = Paginator { cursor in try await notifications.notifications(cursor: cursor) }
    }

    /// Loads the notifications and marks them as read on the server. The list keeps showing
    /// which ones were new until it is refreshed.
    func load() async {
        await paginator.load()
        guard paginator.state.value?.contains(where: { !$0.isRead }) == true else { return }
        try? await notifications.markAllRead()
    }

    /// Where tapping a notification goes.
    static func route(for notification: AppNotification) -> AppRoute {
        switch notification.kind {
        case .follow:
            return .member(notification.actor.id)
        case .postLike, .comment, .commentReply:
            return notification.postID.map(AppRoute.post) ?? .member(notification.actor.id)
        case .recipeSave, .recipeFork:
            return notification.recipeID.map(AppRoute.recipe) ?? .member(notification.actor.id)
        }
    }
}
