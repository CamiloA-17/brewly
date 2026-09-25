import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    enum Scope: Hashable {
        /// The user's posts and those of the people they follow.
        case following
        /// Public posts of the community.
        case explore
    }

    var scope: Scope = .following
    private(set) var paginator: Paginator<Post>
    private(set) var catalog: Catalog = .empty
    private(set) var errorMessage: String?
    /// Notifications the user hasn't seen, for the bell's badge.
    private(set) var unreadCount = 0

    let dependencies: FeedDependencies

    init(dependencies: FeedDependencies) {
        self.dependencies = dependencies
        paginator = Self.makePaginator(scope: .following, posts: dependencies.posts)
    }

    func load() async {
        if catalog.brewMethods.isEmpty, let loaded = try? await dependencies.catalog.catalog() {
            catalog = loaded
        }
        await paginator.load()
    }

    /// Keeps the previous count when offline.
    func refreshUnreadCount() async {
        if let count = try? await dependencies.notifications.unreadCount() {
            unreadCount = count
        }
    }

    /// Shows the posts of the selected scope.
    func reload() async {
        paginator = Self.makePaginator(scope: scope, posts: dependencies.posts)
        await load()
    }

    /// Likes or unlikes a post, updating it right away and reverting on failure.
    func toggleLike(_ post: Post) async {
        let liking = !post.isLiked
        var updated = post
        updated.apply(LikeState(isLiked: liking, likeCount: max(0, post.likeCount + (liking ? 1 : -1))))
        replace(updated)
        do {
            let state = liking
                ? try await dependencies.posts.like(postID: post.id)
                : try await dependencies.posts.unlike(postID: post.id)
            updated.apply(state)
            replace(updated)
            errorMessage = nil
        } catch {
            replace(post)
            errorMessage = error.brewlyMessage
        }
    }

    /// Shows a post the user just published at the top.
    func insert(_ post: Post) {
        paginator.update { $0.insert(post, at: 0) }
    }

    private func replace(_ post: Post) {
        paginator.update { posts in
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = post
            }
        }
    }

    private static func makePaginator(scope: Scope, posts: any PostRepository) -> Paginator<Post> {
        Paginator { cursor in
            switch scope {
            case .following: return try await posts.feed(cursor: cursor)
            case .explore: return try await posts.explore(cursor: cursor)
            }
        }
    }
}
