import BrewlyDomain
import Observation
import SwiftUI

/// Feed paginado por cursor con "me gusta"/"guardar" optimistas.
@MainActor
@Observable
final class FeedViewModel {
    enum Source {
        case home
        case explore(PostKind?)
        case author(UUID)
    }

    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var reachedEnd = false
    var errorMessage: String?

    private let source: Source
    private let social: any SocialRepository
    private let pageSize = 20

    init(source: Source, social: any SocialRepository) {
        self.source = source
        self.social = social
    }

    func refresh() async {
        reachedEnd = false
        await load(reset: true)
    }

    func loadMoreIfNeeded(current post: Post) async {
        guard post.id == posts.last?.id, !reachedEnd, !isLoading else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let cursor = reset ? nil : posts.last?.cursor
            let page: [Post]
            switch source {
            case .home:
                page = try await social.homeFeed(after: cursor, limit: pageSize)
            case .explore(let kind):
                page = try await social.exploreFeed(offset: reset ? 0 : posts.count, limit: pageSize, kind: kind)
            case .author(let id):
                page = try await social.posts(authorID: id, after: cursor, limit: pageSize)
            }
            posts = reset ? page : posts + page
            reachedEnd = page.count < pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func insert(_ post: Post) {
        posts.insert(post, at: 0)
    }

    func toggleLike(_ post: Post) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let liked = !posts[index].likedByMe
        posts[index].likedByMe = liked
        posts[index].likeCount += liked ? 1 : -1
        do {
            try await social.setLiked(liked, postID: post.id)
        } catch {
            // Revierte el cambio optimista.
            if let i = posts.firstIndex(where: { $0.id == post.id }) {
                posts[i].likedByMe = !liked
                posts[i].likeCount += liked ? -1 : 1
            }
            errorMessage = error.localizedDescription
        }
    }

    func toggleSave(_ post: Post) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let saved = !posts[index].savedByMe
        posts[index].savedByMe = saved
        do {
            try await social.setSaved(saved, postID: post.id)
        } catch {
            if let i = posts.firstIndex(where: { $0.id == post.id }) { posts[i].savedByMe = !saved }
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ post: Post) async {
        do {
            try await social.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
