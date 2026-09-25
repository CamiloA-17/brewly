import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Follows, likes, comments, saves and remixes from other members.
public struct NotificationsView: View {
    @State private var model: NotificationsViewModel

    public init(dependencies: NotificationsDependencies) {
        _model = State(initialValue: NotificationsViewModel(dependencies: dependencies))
    }

    public var body: some View {
        AsyncContentView(model.paginator.state, retry: model.load) { notifications in
            if notifications.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No notifications yet", bundle: .module)
                    } icon: {
                        Image(systemName: "bell")
                    }
                } description: {
                    Text("When people follow you or react to your posts and recipes, you'll see it here.", bundle: .module)
                }
            } else {
                List {
                    ForEach(notifications) { notification in
                        NavigationLink(value: NotificationsViewModel.route(for: notification)) {
                            NotificationRow(notification: notification)
                        }
                        .listRowBackground(notification.isRead ? nil : Color.brewlyCrema.opacity(0.35))
                    }
                    if model.paginator.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .task { await model.paginator.loadMore() }
                    }
                }
                .refreshable { await model.load() }
            }
        }
        .navigationTitle(Text("Notifications", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            AvatarView(name: notification.actor.displayName, url: notification.actor.avatarURL, size: 40)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: icon)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.brewlyAccent, in: Circle())
                        .offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 2) {
                message
                if let excerpt = notification.commentExcerpt ?? notification.postExcerpt {
                    Text(excerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(notification.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var message: Text {
        let name = notification.actor.displayName
        let title = notification.recipeTitle ?? ""
        return switch notification.kind {
        case .follow: Text("\(name) started following you.", bundle: .module)
        case .postLike: Text("\(name) liked your post.", bundle: .module)
        case .comment: Text("\(name) commented on your post.", bundle: .module)
        case .commentReply: Text("\(name) replied to your comment.", bundle: .module)
        case .recipeSave: Text("\(name) saved your recipe \(title).", bundle: .module)
        case .recipeFork: Text("\(name) remixed your recipe: \(title).", bundle: .module)
        }
    }

    private var icon: String {
        switch notification.kind {
        case .follow: "person.fill.badge.plus"
        case .postLike: "heart.fill"
        case .comment, .commentReply: "bubble.right.fill"
        case .recipeSave: "bookmark.fill"
        case .recipeFork: "arrow.triangle.branch"
        }
    }
}
