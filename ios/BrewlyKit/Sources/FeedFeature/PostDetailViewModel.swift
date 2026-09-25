import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class PostDetailViewModel {
    private(set) var state: LoadState<Post> = .idle
    private(set) var catalog: Catalog = .empty
    let comments: Paginator<PostComment>
    var newComment = ""
    /// The comment the new one replies to.
    private(set) var replyingTo: PostComment?
    private(set) var isSending = false
    private(set) var errorMessage: String?

    let postID: UUID
    private let dependencies: FeedDependencies

    init(postID: UUID, dependencies: FeedDependencies) {
        self.postID = postID
        self.dependencies = dependencies
        let posts = dependencies.posts
        comments = Paginator { cursor in try await posts.comments(postID: postID, cursor: cursor) }
    }

    var isAuthor: Bool {
        state.value?.author.id == dependencies.currentUserID
    }

    var canSend: Bool {
        !isSending && PostRules.validateComment(body: newComment).isEmpty
    }

    /// Top-level comments in order, each followed by its replies.
    var threadedComments: [PostComment] {
        let all = comments.state.value ?? []
        let loadedIDs = Set(all.map(\.id))
        let replies = Dictionary(grouping: all.filter { $0.parentID.map(loadedIDs.contains) == true }, by: { $0.parentID! })
        return all.filter { $0.parentID.map(loadedIDs.contains) != true }.flatMap { [$0] + (replies[$0.id] ?? []) }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let post = dependencies.posts.post(id: postID)
            async let catalog = dependencies.catalog.catalog()
            let (loadedPost, loadedCatalog) = try await (post, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedPost)
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
            return
        }
        await comments.load()
    }

    func toggleLike() async {
        guard let post = state.value else { return }
        let liking = !post.isLiked
        var updated = post
        updated.apply(LikeState(isLiked: liking, likeCount: max(0, post.likeCount + (liking ? 1 : -1))))
        state = .loaded(updated)
        do {
            let like = liking
                ? try await dependencies.posts.like(postID: postID)
                : try await dependencies.posts.unlike(postID: postID)
            updated.apply(like)
            state = .loaded(updated)
        } catch {
            state = .loaded(post)
            errorMessage = error.brewlyMessage
        }
    }

    func reply(to comment: PostComment?) {
        replyingTo = comment
    }

    /// Posts the new comment and adds it to the thread.
    func send() async {
        guard canSend else { return }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await dependencies.posts.addComment(
                postID: postID, body: newComment.trimmingWhitespace, parentID: replyingTo?.id
            )
            comments.update { $0.append(comment) }
            changeCommentCount(by: 1)
            newComment = ""
            replyingTo = nil
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }

    /// Deletes a comment and its replies.
    func delete(_ comment: PostComment) async {
        do {
            try await dependencies.posts.deleteComment(id: comment.id)
            var removed = 0
            comments.update { list in
                let before = list.count
                list.removeAll { $0.id == comment.id || $0.parentID == comment.id }
                removed = before - list.count
            }
            changeCommentCount(by: -removed)
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }

    /// Returns `true` when the post was deleted.
    func deletePost() async -> Bool {
        do {
            try await dependencies.posts.delete(id: postID)
            return true
        } catch {
            errorMessage = error.brewlyMessage
            return false
        }
    }

    private func changeCommentCount(by delta: Int) {
        guard var post = state.value else { return }
        post.commentCount = max(0, post.commentCount + delta)
        state = .loaded(post)
    }
}
