import BrewlyDesignSystem
import BrewlyDomain
import Foundation
@testable import NotificationsFeature
import Testing

actor FakeNotificationRepository: NotificationRepository {
    var items: [AppNotification]
    private(set) var markedRead = 0

    init(items: [AppNotification]) {
        self.items = items
    }

    func notifications(cursor: String?) async throws -> PagedResult<AppNotification> {
        PagedResult(items: items, nextCursor: nil)
    }

    func unreadCount() async throws -> Int { items.filter { !$0.isRead }.count }

    func markAllRead() async throws {
        markedRead += 1
        items = items.map { var item = $0; item.isRead = true; return item }
    }
}

private let leo = UserSummary(id: UUID(), username: "leo.roaster", displayName: "Leo")

@MainActor
@Suite("NotificationsViewModel")
struct NotificationsViewModelTests {
    @Test("Opening the list marks everything read but keeps showing what was new")
    func marksRead() async {
        let repository = FakeNotificationRepository(items: [AppNotification(id: UUID(), kind: .follow, actor: leo)])
        let model = NotificationsViewModel(dependencies: NotificationsDependencies(notifications: repository))
        await model.load()
        #expect(await repository.markedRead == 1)
        #expect(model.paginator.state.value?.first?.isRead == false)
        #expect(await repository.unreadCount() == 0)
    }

    @Test("Nothing is marked when everything was read")
    func nothingNew() async {
        let repository = FakeNotificationRepository(items: [AppNotification(id: UUID(), kind: .follow, actor: leo, isRead: true)])
        let model = NotificationsViewModel(dependencies: NotificationsDependencies(notifications: repository))
        await model.load()
        #expect(await repository.markedRead == 0)
    }

    @Test("Each notification opens what it is about")
    func routes() {
        let postID = UUID()
        let recipeID = UUID()
        #expect(NotificationsViewModel.route(for: AppNotification(id: UUID(), kind: .follow, actor: leo)) == .member(leo.id))
        #expect(NotificationsViewModel.route(for: AppNotification(id: UUID(), kind: .commentReply, actor: leo, postID: postID))
                == .post(postID))
        #expect(NotificationsViewModel.route(for: AppNotification(id: UUID(), kind: .recipeFork, actor: leo, recipeID: recipeID))
                == .recipe(recipeID))
        // A notification whose target is gone opens the member instead.
        #expect(NotificationsViewModel.route(for: AppNotification(id: UUID(), kind: .postLike, actor: leo)) == .member(leo.id))
    }
}
