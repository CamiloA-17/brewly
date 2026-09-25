import BrewlyDomain
import Foundation
@testable import PeopleFeature
import Testing

struct StubCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog { .empty }
}

struct EmptyPostRepository: PostRepository {
    func feed(cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [], nextCursor: nil) }
    func explore(cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [], nextCursor: nil) }
    func posts(of memberID: UUID, cursor: String?) async throws -> PagedResult<Post> { PagedResult(items: [], nextCursor: nil) }
    func post(id: UUID) async throws -> Post { throw DomainError.notFound }
    func create(_ draft: PostDraft) async throws -> Post { throw DomainError.notFound }
    func delete(id: UUID) async throws {}
    func like(postID: UUID) async throws -> LikeState { LikeState(isLiked: true, likeCount: 1) }
    func unlike(postID: UUID) async throws -> LikeState { LikeState(isLiked: false, likeCount: 0) }
    func comments(postID: UUID, cursor: String?) async throws -> PagedResult<Comment> { PagedResult(items: [], nextCursor: nil) }
    func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> Comment { throw DomainError.notFound }
    func deleteComment(id: UUID) async throws {}
}

/// In-memory people graph seen by one viewer.
actor FakePeopleRepository: PeopleRepository {
    var member: MemberProfile
    var failing = false
    private(set) var searches: [String] = []
    private(set) var recipeLoads = 0

    init(profile: MemberProfile) {
        member = profile
    }

    func setFailing(_ failing: Bool) { self.failing = failing }

    func search(_ query: String) async throws -> [UserSummary] {
        searches.append(query)
        return [member.summary]
    }

    func profile(id: UUID) async throws -> MemberProfile { member }

    func recipes(of memberID: UUID, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        recipeLoads += 1
        return PagedResult(items: [], nextCursor: nil)
    }

    func followers(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary> {
        PagedResult(items: [], nextCursor: nil)
    }

    func following(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary> {
        PagedResult(items: [], nextCursor: nil)
    }

    func follow(_ memberID: UUID) async throws -> FollowState {
        if failing { throw DomainError.offline }
        member.isFollowing = true
        member.followerCount += 1
        return FollowState(isFollowing: true, followerCount: member.followerCount)
    }

    func unfollow(_ memberID: UUID) async throws -> FollowState {
        if failing { throw DomainError.offline }
        member.isFollowing = false
        member.followerCount -= 1
        return FollowState(isFollowing: false, followerCount: member.followerCount)
    }
}

private let leo = MemberProfile(id: UUID(), username: "leo.roaster", displayName: "Leo", followerCount: 4)

@MainActor
@Suite("MemberProfileViewModel")
struct MemberProfileViewModelTests {
    private func makeModel(_ people: FakePeopleRepository) -> MemberProfileViewModel {
        MemberProfileViewModel(
            memberID: leo.id,
            dependencies: PeopleDependencies(people: people, posts: EmptyPostRepository(), catalog: StubCatalogRepository())
        )
    }

    @Test("Loading shows the profile and the member's recipes")
    func load() async {
        let people = FakePeopleRepository(profile: leo)
        let model = makeModel(people)
        await model.load()
        #expect(model.state.value?.username == "leo.roaster")
        #expect(model.recipes.state.value?.isEmpty == true)
        #expect(await people.recipeLoads == 1)
    }

    @Test("Following updates the count and reloads recipes that may now be visible")
    func follow() async {
        let people = FakePeopleRepository(profile: leo)
        let model = makeModel(people)
        await model.load()
        await model.toggleFollow()
        #expect(model.state.value?.isFollowing == true)
        #expect(model.state.value?.followerCount == 5)
        #expect(await people.recipeLoads == 2)

        await model.toggleFollow()
        #expect(model.state.value?.isFollowing == false)
        #expect(model.state.value?.followerCount == 4)
    }

    @Test("A failed follow reverts the change and shows an error")
    func failedFollow() async {
        let people = FakePeopleRepository(profile: leo)
        let model = makeModel(people)
        await model.load()
        await people.setFailing(true)
        await model.toggleFollow()
        #expect(model.state.value?.isFollowing == false)
        #expect(model.state.value?.followerCount == 4)
        #expect(model.errorMessage != nil)
    }

    @Test("The posts tab loads the member's posts")
    func postsTab() async {
        let model = makeModel(FakePeopleRepository(profile: leo))
        await model.load()
        #expect(model.posts.state.value == nil)
        model.tab = .posts
        await model.loadTab()
        #expect(model.posts.state.value?.isEmpty == true)
    }

    @Test("Your own profile has no follow button action")
    func ownProfile() async {
        var me = leo
        me.isMe = true
        let people = FakePeopleRepository(profile: me)
        let model = makeModel(people)
        await model.load()
        await model.toggleFollow()
        #expect(model.state.value?.isFollowing == false)
    }
}

@MainActor
@Suite("MemberSearchViewModel")
struct MemberSearchViewModelTests {
    @Test("Blank queries don't hit the API")
    func blankQuery() async {
        let people = FakePeopleRepository(profile: leo)
        let model = MemberSearchViewModel(people: people)
        model.query = "   "
        await model.search()
        #expect(model.results.isEmpty)
        #expect(await people.searches.isEmpty)
    }

    @Test("Queries are trimmed before searching")
    func search() async {
        let people = FakePeopleRepository(profile: leo)
        let model = MemberSearchViewModel(people: people)
        model.query = " leo "
        await model.search()
        #expect(await people.searches == ["leo"])
        #expect(model.results.map(\.username) == ["leo.roaster"])
    }
}
