import BrewlyDomain
@testable import FeedFeature
import Foundation
import Testing

private let ana = UserSummary(id: UUID(), username: "ana.barista", displayName: "Ana")
private let leo = UserSummary(id: UUID(), username: "leo.roaster", displayName: "Leo")

/// An in-memory post with its comments; likes fail when `failing` is set.
actor FakePostRepository: PostRepository {
    var post: Post
    var comments: [PostComment] = []
    var failing = false
    private(set) var created: [PostDraft] = []

    init(post: Post) {
        self.post = post
    }

    func setFailing(_ failing: Bool) { self.failing = failing }
    func setComments(_ comments: [PostComment]) { self.comments = comments }

    func feed(cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [post], nextCursor: nil) }
    func explore(cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [], nextCursor: nil) }
    func posts(of memberID: UUID, cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [post], nextCursor: nil) }
    func post(id: UUID) async throws -> Post { post }

    func create(_ draft: PostDraft) async throws -> Post {
        created.append(draft)
        return Post(id: UUID(), author: ana, body: draft.body)
    }

    func delete(id: UUID) async throws {}

    func like(postID: UUID) async throws -> LikeState {
        if failing { throw DomainError.offline }
        post.apply(LikeState(isLiked: true, likeCount: post.likeCount + 1))
        return LikeState(isLiked: true, likeCount: post.likeCount)
    }

    func unlike(postID: UUID) async throws -> LikeState {
        if failing { throw DomainError.offline }
        post.apply(LikeState(isLiked: false, likeCount: post.likeCount - 1))
        return LikeState(isLiked: false, likeCount: post.likeCount)
    }

    func comments(postID: UUID, cursor: String?) async throws -> PagedResult<PostComment> {
        PagedResult(items: comments, nextCursor: nil)
    }

    func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> PostComment {
        let comment = PostComment(id: UUID(), postID: postID, parentID: parentID, author: ana, body: body, canDelete: true)
        comments.append(comment)
        return comment
    }

    func deleteComment(id: UUID) async throws {
        comments.removeAll { $0.id == id || $0.parentID == id }
    }
}

struct EmptyCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog { .empty }
}

struct EmptyRecipeRepository: RecipeRepository {
    func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> { PagedResult(items: [], nextCursor: nil) }
    func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        PagedResult(items: [], nextCursor: nil)
    }
    func recipe(id: UUID) async throws -> Recipe { throw DomainError.notFound }
    func create(_ input: RecipeInput) async throws -> Recipe { throw DomainError.notFound }
    func update(id: UUID, _ input: RecipeInput) async throws -> Recipe { throw DomainError.notFound }
    func delete(id: UUID) async throws {}
}

struct EmptyBeanRepository: BeanRepository {
    func myBeans(includeArchived: Bool) async throws -> [Bean] { [] }
    func bean(id: UUID) async throws -> Bean { throw DomainError.notFound }
    func create(_ draft: BeanDraft) async throws -> Bean { throw DomainError.notFound }
    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean { throw DomainError.notFound }
    func delete(id: UUID) async throws {}
}

func makeDependencies(_ posts: FakePostRepository, currentUserID: UUID = ana.id) -> FeedDependencies {
    FeedDependencies(
        posts: posts, recipes: EmptyRecipeRepository(), beans: EmptyBeanRepository(),
        catalog: EmptyCatalogRepository(), currentUserID: currentUserID
    )
}

@MainActor
@Suite("FeedViewModel")
struct FeedViewModelTests {
    @Test("Liking updates the post with the server's count")
    func like() async throws {
        let posts = FakePostRepository(post: Post(id: UUID(), author: leo, body: "Morning V60", likeCount: 2))
        let model = FeedViewModel(dependencies: makeDependencies(posts))
        await model.load()
        let post = try #require(model.paginator.state.value?.first)
        await model.toggleLike(post)
        #expect(model.paginator.state.value?.first?.isLiked == true)
        #expect(model.paginator.state.value?.first?.likeCount == 3)
    }

    @Test("A failed like is reverted")
    func failedLike() async throws {
        let posts = FakePostRepository(post: Post(id: UUID(), author: leo, body: "Morning V60", likeCount: 2))
        await posts.setFailing(true)
        let model = FeedViewModel(dependencies: makeDependencies(posts))
        await model.load()
        let post = try #require(model.paginator.state.value?.first)
        await model.toggleLike(post)
        #expect(model.paginator.state.value?.first?.isLiked == false)
        #expect(model.paginator.state.value?.first?.likeCount == 2)
        #expect(model.errorMessage != nil)
    }

    @Test("A new post shows at the top")
    func insert() async {
        let posts = FakePostRepository(post: Post(id: UUID(), author: leo, body: "Older"))
        let model = FeedViewModel(dependencies: makeDependencies(posts))
        await model.load()
        model.insert(Post(id: UUID(), author: ana, body: "Newer"))
        #expect(model.paginator.state.value?.map(\.body) == ["Newer", "Older"])
    }
}

@MainActor
@Suite("ComposePostViewModel")
struct ComposePostViewModelTests {
    @Test("An empty post is not sent")
    func empty() async {
        let posts = FakePostRepository(post: Post(id: UUID(), author: ana))
        let model = ComposePostViewModel(dependencies: makeDependencies(posts))
        #expect(!model.canPublish)
        #expect(await model.publish() == nil)
        #expect(model.violations.map(\.field) == ["body"])
        #expect(await posts.created.isEmpty)
    }

    @Test("Photos are limited to four and the draft is sent")
    func publish() async {
        let posts = FakePostRepository(post: Post(id: UUID(), author: ana))
        let model = ComposePostViewModel(dependencies: makeDependencies(posts))
        model.setPhotos((0..<6).map { Data([UInt8($0)]) })
        #expect(model.draft.photos.count == 4)
        model.draft.body = "Latte art practice"
        let post = await model.publish()
        #expect(post?.body == "Latte art practice")
        #expect(await posts.created.first?.photos.count == 4)
    }

    @Test("Switching what to share clears the other attachment")
    func attachment() {
        let model = ComposePostViewModel(dependencies: makeDependencies(FakePostRepository(post: Post(id: UUID(), author: ana))))
        model.draft.recipeID = UUID()
        model.select(.bean)
        #expect(model.draft.recipeID == nil)
        model.select(.none)
        #expect(model.draft.beanID == nil && model.draft.recipeID == nil)
    }
}

@MainActor
@Suite("PostDetailViewModel")
struct PostDetailViewModelTests {
    @Test("Replies are shown under their comment")
    func threads() async {
        let postID = UUID()
        let first = PostComment(id: UUID(), postID: postID, author: leo, body: "What grinder?")
        let second = PostComment(id: UUID(), postID: postID, author: leo, body: "Lovely")
        let reply = PostComment(id: UUID(), postID: postID, parentID: first.id, author: ana, body: "Comandante")
        let posts = FakePostRepository(post: Post(id: postID, author: ana, body: "V60", commentCount: 3))
        await posts.setComments([first, second, reply])
        let model = PostDetailViewModel(postID: postID, dependencies: makeDependencies(posts))
        await model.load()
        #expect(model.threadedComments.map(\.body) == ["What grinder?", "Comandante", "Lovely"])
        #expect(model.isAuthor)
    }

    @Test("Sending a reply adds it and updates the count; deleting removes its thread")
    func sendAndDelete() async throws {
        let postID = UUID()
        let first = PostComment(id: UUID(), postID: postID, author: leo, body: "What grinder?", canDelete: true)
        let posts = FakePostRepository(post: Post(id: postID, author: ana, body: "V60", commentCount: 1))
        await posts.setComments([first])
        let model = PostDetailViewModel(postID: postID, dependencies: makeDependencies(posts))
        await model.load()

        model.newComment = "   "
        #expect(!model.canSend)
        model.reply(to: first)
        model.newComment = " Comandante "
        await model.send()
        #expect(model.newComment.isEmpty)
        #expect(model.replyingTo == nil)
        #expect(model.state.value?.commentCount == 2)
        let reply = try #require(model.comments.state.value?.last)
        #expect(reply.body == "Comandante" && reply.parentID == first.id)

        await model.delete(first)
        #expect(model.comments.state.value?.isEmpty == true)
        #expect(model.state.value?.commentCount == 0)
    }
}
