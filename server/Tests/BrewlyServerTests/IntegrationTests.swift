@testable import BrewlyServer
import BrewlyAPI
import FluentKit
import SQLKit
import XCTVapor

/// End-to-end tests against a real, migrated PostgreSQL database.
///
/// They run only when `TEST_DATABASE_URL` is set, because every test truncates all user data.
/// Tokens are signed with the `JWT_SECRET` of the environment (`make server-test` loads it from `.env`):
///
///     TEST_DATABASE_URL=postgres://<user>:<password>@localhost:5432/brewly_test make server-test
final class IntegrationTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        guard let url = ProcessInfo.processInfo.environment["TEST_DATABASE_URL"], !url.isEmpty else {
            throw XCTSkip("Set TEST_DATABASE_URL to run integration tests.")
        }
        guard (ProcessInfo.processInfo.environment["JWT_SECRET"]?.count ?? 0) >= 32 else {
            throw ConfigurationError("Set JWT_SECRET (at least 32 characters) to run integration tests.")
        }
        setenv("DATABASE_URL", url, 1)

        app = try await Application.make(.testing)
        try await configure(app)
        app.passwords.use(.plaintext)
        try await app.db.sql.raw("TRUNCATE users CASCADE").run()
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }

    // MARK: - Auth

    func testRegisterLoginRefreshAndLogout() async throws {
        let registered = try await register("ana.barista")
        XCTAssertEqual(registered.user.username, "ana.barista")
        XCTAssertEqual(registered.user.email, "ana.barista@example.com")

        let loggedIn: AuthResponse = try await send(.POST, "v1/auth/login",
            body: LoginRequest(email: "ANA.BARISTA@example.com", password: "test-password"))
        XCTAssertEqual(loggedIn.user.id, registered.user.id)

        try await expectError(.POST, "v1/auth/login",
            body: LoginRequest(email: "ana.barista@example.com", password: "wrong-password"),
            status: .unauthorized, code: APIErrorCode.invalidCredentials)

        let refreshed: AuthResponse = try await send(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: loggedIn.refreshToken))
        XCTAssertNotEqual(refreshed.refreshToken, loggedIn.refreshToken)

        // A consumed refresh token cannot be reused, and reusing it revokes the session.
        try await expectError(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: loggedIn.refreshToken), status: .unauthorized)
        try await expectError(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: refreshed.refreshToken), status: .unauthorized)
    }

    func testRegistrationConflictsAndValidation() async throws {
        _ = try await register("ana.barista")
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "other@example.com", password: "test-password", username: "ana.barista", displayName: "Ana"),
            status: .conflict, code: APIErrorCode.usernameTaken)
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "ana.barista@example.com", password: "test-password", username: "ana2", displayName: "Ana"),
            status: .conflict, code: APIErrorCode.emailTaken)
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "nope", password: "short", username: "A", displayName: ""),
            status: .unprocessableEntity, code: APIErrorCode.validationFailed)
    }

    func testProtectedRoutesRequireAToken() async throws {
        try await expectError(.GET, "v1/me", status: .unauthorized, code: APIErrorCode.unauthorized)
    }

    // MARK: - Catalog and methods

    func testCatalogAndMyMethods() async throws {
        let ana = try await register("ana.barista")
        let catalog: CatalogDTO = try await send(.GET, "v1/catalog", token: ana.accessToken)
        XCTAssertTrue(catalog.brewMethods.contains { $0.slug == "espresso" && $0.ratioBasis == .beverage })
        XCTAssertFalse(catalog.varietals.isEmpty)
        XCTAssertFalse(catalog.countries.isEmpty)

        try await expectStatus(.PUT, "v1/me/methods/v60", token: ana.accessToken, status: .noContent)
        try await expectStatus(.PUT, "v1/me/methods/v60", token: ana.accessToken, status: .noContent)
        try await expectError(.PUT, "v1/me/methods/teapot", token: ana.accessToken, status: .notFound)
        let methods: UserMethodsDTO = try await send(.GET, "v1/me/methods", token: ana.accessToken)
        XCTAssertEqual(methods.methodSlugs, ["v60"])
    }

    // MARK: - Beans and recipes

    func testBeanAndRecipeLifecycle() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        XCTAssertEqual(bean.varietalSlugs, ["geisha"])
        XCTAssertEqual(bean.roastDate, CalendarDate(year: 2026, month: 9, day: 1))

        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))
        XCTAssertEqual(recipe.ratio, 16.67)
        XCTAssertEqual(recipe.extractionYieldPercent, 19.78)
        XCTAssertEqual(recipe.steps.map(\.position), [1, 2])
        XCTAssertEqual(recipe.bean.id, bean.id)

        let mine: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/me/recipes", token: ana.accessToken)
        XCTAssertEqual(mine.items.map(\.id), [recipe.id])

        var edit = Self.v60(beanID: bean.id)
        edit.title = "Floral V60 v2"
        edit.steps = []
        let updated: RecipeDTO = try await send(.PUT, "v1/recipes/\(recipe.id)", token: ana.accessToken, body: edit)
        XCTAssertEqual(updated.title, "Floral V60 v2")
        XCTAssertTrue(updated.steps.isEmpty)

        // A bean used by a recipe cannot be deleted, but it can be archived.
        try await expectError(.DELETE, "v1/beans/\(bean.id)", token: ana.accessToken,
                              status: .conflict, code: APIErrorCode.beanInUse)
        var archive = Self.geisha
        archive.isArchived = true
        let archived: BeanDTO = try await send(.PUT, "v1/beans/\(bean.id)", token: ana.accessToken, body: archive)
        XCTAssertTrue(archived.isArchived)
        let active: [BeanDTO] = try await send(.GET, "v1/me/beans", token: ana.accessToken)
        XCTAssertTrue(active.isEmpty)
        let all: [BeanDTO] = try await send(.GET, "v1/me/beans?includeArchived=true", token: ana.accessToken)
        XCTAssertEqual(all.count, 1)

        try await expectStatus(.DELETE, "v1/recipes/\(recipe.id)", token: ana.accessToken, status: .noContent)
        try await expectStatus(.DELETE, "v1/beans/\(bean.id)", token: ana.accessToken, status: .noContent)
    }

    func testRecipeValidationUsesTheMethodRatioBasis() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)

        var espresso = Self.v60(beanID: bean.id)
        espresso.methodSlug = "espresso"
        let error = try await expectError(.POST, "v1/recipes", token: ana.accessToken, body: espresso,
                                          status: .unprocessableEntity, code: APIErrorCode.validationFailed)
        XCTAssertEqual(Set(error.fieldErrors?.map(\.field) ?? []), ["waterG"])

        espresso.waterG = nil
        espresso.yieldG = 36
        espresso.tdsPercent = 9
        let shot: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: espresso)
        XCTAssertEqual(shot.ratio, 2.4)
    }

    func testOwnershipAndVisibility() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)

        var privateRecipe = Self.v60(beanID: bean.id)
        privateRecipe.visibility = .private
        let hidden: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: privateRecipe)
        let shared: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        try await expectError(.GET, "v1/recipes/\(hidden.id)", token: leo.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/recipes/\(shared.id)", token: leo.accessToken,
                              body: Self.v60(beanID: bean.id), status: .notFound)
        try await expectError(.DELETE, "v1/recipes/\(shared.id)", token: leo.accessToken, status: .notFound)

        // Leo cannot brew with Ana's bean.
        let error = try await expectError(.POST, "v1/recipes", token: leo.accessToken,
                                          body: Self.v60(beanID: bean.id), status: .unprocessableEntity)
        XCTAssertEqual(error.fieldErrors?.map(\.field), ["beanId"])

        let explore: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?method=v60&country=co", token: leo.accessToken)
        XCTAssertEqual(explore.items.map(\.id), [shared.id])
    }

    func testExplorePagination() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        var created: [UUID] = []
        for _ in 0..<3 {
            let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))
            created.append(recipe.id)
        }
        let first: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?limit=2", token: ana.accessToken)
        XCTAssertEqual(first.items.count, 2)
        let cursor = try XCTUnwrap(first.nextCursor)
        let second: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?limit=2&cursor=\(cursor)", token: ana.accessToken)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertNil(second.nextCursor)
        XCTAssertEqual(Set((first.items + second.items).map(\.id)), Set(created))
    }

    func testDeleteAccountRemovesEverything() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let _: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        try await expectStatus(.DELETE, "v1/me", token: ana.accessToken, status: .noContent)
        try await expectError(.GET, "v1/me", token: ana.accessToken, status: .unauthorized)
        let remaining = try await app.db.sql.raw("SELECT count(*) AS count FROM recipes").first()
        XCTAssertEqual(try remaining?.decode(column: "count", as: Int.self), 0)
    }

    // MARK: - People, follows, saves and remixes

    func testProfilesAndFollows() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let eve = try await register("eve.brews")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        var followersOnly = Self.v60(beanID: bean.id)
        followersOnly.visibility = .followers
        let _: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: followersOnly)

        let before: UserProfileDTO = try await send(.GET, "v1/users/\(ana.user.id)", token: leo.accessToken)
        XCTAssertEqual(before.recipeCount, 0)
        XCTAssertFalse(before.isFollowing)
        XCTAssertFalse(before.isMe)

        // Following twice is idempotent.
        let followed: FollowStateDTO = try await send(.PUT, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)
        XCTAssertEqual(followed, FollowStateDTO(isFollowing: true, followerCount: 1))
        let again: FollowStateDTO = try await send(.PUT, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)
        XCTAssertEqual(again.followerCount, 1)
        let _: FollowStateDTO = try await send(.PUT, "v1/users/\(ana.user.id)/follow", token: eve.accessToken)

        // Followers-only recipes become visible to followers.
        let after: UserProfileDTO = try await send(.GET, "v1/users/\(ana.user.id)", token: leo.accessToken)
        XCTAssertEqual(after.recipeCount, 1)
        XCTAssertEqual(after.followerCount, 2)
        XCTAssertTrue(after.isFollowing)
        let recipes: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(
            .GET, "v1/users/\(ana.user.id)/recipes", token: leo.accessToken)
        XCTAssertEqual(recipes.items.count, 1)

        let leoSeenByAna: UserProfileDTO = try await send(.GET, "v1/users/\(leo.user.id)", token: ana.accessToken)
        XCTAssertTrue(leoSeenByAna.followsYou)
        let mine: UserProfileDTO = try await send(.GET, "v1/users/\(ana.user.id)", token: ana.accessToken)
        XCTAssertTrue(mine.isMe)

        // Followers are listed newest first and paginated.
        let firstPage: BrewlyAPI.Page<UserSummaryDTO> = try await send(
            .GET, "v1/users/\(ana.user.id)/followers?limit=1", token: leo.accessToken)
        XCTAssertEqual(firstPage.items.map(\.id), [eve.user.id])
        let cursor = try XCTUnwrap(firstPage.nextCursor)
        let secondPage: BrewlyAPI.Page<UserSummaryDTO> = try await send(
            .GET, "v1/users/\(ana.user.id)/followers?limit=1&cursor=\(cursor)", token: leo.accessToken)
        XCTAssertEqual(secondPage.items.map(\.id), [leo.user.id])
        XCTAssertNil(secondPage.nextCursor)
        let following: BrewlyAPI.Page<UserSummaryDTO> = try await send(
            .GET, "v1/users/\(leo.user.id)/following", token: ana.accessToken)
        XCTAssertEqual(following.items.map(\.id), [ana.user.id])

        let unfollowed: FollowStateDTO = try await send(.DELETE, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)
        XCTAssertEqual(unfollowed, FollowStateDTO(isFollowing: false, followerCount: 1))

        try await expectError(.PUT, "v1/users/\(leo.user.id)/follow", token: leo.accessToken,
                              status: .unprocessableEntity, code: APIErrorCode.cannotFollowSelf)
        try await expectError(.GET, "v1/users/\(UUID())", token: leo.accessToken, status: .notFound)
    }

    func testSearchAndBlocksHideMembers() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let _ = try await register("anabel_m")

        let results: [UserSummaryDTO] = try await send(.GET, "v1/users?q=%40ANA", token: leo.accessToken)
        XCTAssertEqual(results.map(\.username), ["ana.barista", "anabel_m"])
        // "_" is not a wildcard.
        let literal: [UserSummaryDTO] = try await send(.GET, "v1/users?q=ana_", token: leo.accessToken)
        XCTAssertTrue(literal.isEmpty)

        // Blocking is not in the API yet; a block hides members from each other everywhere.
        try await app.db.sql.raw("""
            INSERT INTO user_blocks (blocker_id, blocked_id) VALUES (\(bind: ana.user.id), \(bind: leo.user.id))
            """).run()
        try await expectError(.GET, "v1/users/\(ana.user.id)", token: leo.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/users/\(ana.user.id)/follow", token: leo.accessToken, status: .notFound)
        let afterBlock: [UserSummaryDTO] = try await send(.GET, "v1/users?q=ana", token: leo.accessToken)
        XCTAssertEqual(afterBlock.map(\.username), ["anabel_m"])
    }

    func testSavesAndRemixes() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let anaBean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let leoBean: BeanDTO = try await send(.POST, "v1/beans", token: leo.accessToken, body: Self.geisha)
        let original: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: anaBean.id))
        var privateRecipe = Self.v60(beanID: anaBean.id)
        privateRecipe.visibility = .private
        let hidden: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: privateRecipe)

        // Saving is idempotent and only works on visible recipes.
        let saved: SaveStateDTO = try await send(.PUT, "v1/recipes/\(original.id)/save", token: leo.accessToken)
        XCTAssertEqual(saved, SaveStateDTO(isSaved: true, saveCount: 1))
        let savedAgain: SaveStateDTO = try await send(.PUT, "v1/recipes/\(original.id)/save", token: leo.accessToken)
        XCTAssertEqual(savedAgain.saveCount, 1)
        try await expectError(.PUT, "v1/recipes/\(hidden.id)/save", token: leo.accessToken, status: .notFound)

        let savedList: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/me/saved-recipes", token: leo.accessToken)
        XCTAssertEqual(savedList.items.map(\.id), [original.id])

        // A remix uses the remixer's own bean and links to the original.
        var remixRequest = Self.v60(beanID: leoBean.id)
        remixRequest.forkedFromId = original.id
        remixRequest.title = "Floral V60, finer"
        let remix: RecipeDTO = try await send(.POST, "v1/recipes", token: leo.accessToken, body: remixRequest)
        XCTAssertEqual(remix.forkedFromId, original.id)
        XCTAssertEqual(remix.forkedFrom?.title, original.title)
        XCTAssertEqual(remix.forkedFrom?.author.id, ana.user.id)

        let seenByLeo: RecipeDTO = try await send(.GET, "v1/recipes/\(original.id)", token: leo.accessToken)
        XCTAssertEqual(seenByLeo.saveCount, 1)
        XCTAssertEqual(seenByLeo.forkCount, 1)
        XCTAssertTrue(seenByLeo.isSaved)
        let seenByAna: RecipeDTO = try await send(.GET, "v1/recipes/\(original.id)", token: ana.accessToken)
        XCTAssertFalse(seenByAna.isSaved)

        // Recipes the remixer can't see can't be remixed.
        remixRequest.forkedFromId = hidden.id
        let error = try await expectError(.POST, "v1/recipes", token: leo.accessToken,
                                          body: remixRequest, status: .unprocessableEntity)
        XCTAssertEqual(error.fieldErrors?.map(\.field), ["forkedFromId"])

        let unsaved: SaveStateDTO = try await send(.DELETE, "v1/recipes/\(original.id)/save", token: leo.accessToken)
        XCTAssertEqual(unsaved, SaveStateDTO(isSaved: false, saveCount: 0))

        // Deleting the original keeps the remix, without the link.
        try await expectStatus(.DELETE, "v1/recipes/\(original.id)", token: ana.accessToken, status: .noContent)
        let orphan: RecipeDTO = try await send(.GET, "v1/recipes/\(remix.id)", token: leo.accessToken)
        XCTAssertNil(orphan.forkedFromId)
        XCTAssertNil(orphan.forkedFrom)
    }

    // MARK: - Media, posts, likes and comments

    func testPhotoPostsFeedAndMediaAccess() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let eve = try await register("eve.brews")
        let _: FollowStateDTO = try await send(.PUT, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)

        let photo = try await upload(tinyJPEG(width: 800, height: 600), token: ana.accessToken)
        XCTAssertEqual(photo.width, 800)
        XCTAssertEqual(photo.url, "/v1/media/\(photo.id.uuidString.lowercased())")
        try await expectStatus(.GET, "v1/media/\(photo.id)", token: ana.accessToken, status: .ok)
        // Nobody else can see an image until it is in a post they can see.
        try await expectError(.GET, "v1/media/\(photo.id)", token: leo.accessToken, status: .notFound)

        let post: PostDTO = try await send(.POST, "v1/posts", token: ana.accessToken,
            body: CreatePostRequest(mediaIds: [photo.id], visibility: .followers))
        XCTAssertEqual(post.kind, .text)
        XCTAssertEqual(post.media.map(\.id), [photo.id])

        try await expectStatus(.GET, "v1/media/\(photo.id)", token: leo.accessToken, status: .ok)
        try await expectError(.GET, "v1/media/\(photo.id)", token: eve.accessToken, status: .notFound)
        try await expectError(.GET, "v1/posts/\(post.id)", token: eve.accessToken, status: .notFound)

        let leoFeed: BrewlyAPI.Page<PostDTO> = try await send(.GET, "v1/feed", token: leo.accessToken)
        XCTAssertEqual(leoFeed.items.map(\.id), [post.id])
        let eveFeed: BrewlyAPI.Page<PostDTO> = try await send(.GET, "v1/feed", token: eve.accessToken)
        XCTAssertTrue(eveFeed.items.isEmpty)
        let explore: BrewlyAPI.Page<PostDTO> = try await send(.GET, "v1/posts/explore", token: eve.accessToken)
        XCTAssertTrue(explore.items.isEmpty)
        let anaPosts: BrewlyAPI.Page<PostDTO> = try await send(.GET, "v1/users/\(ana.user.id)/posts", token: leo.accessToken)
        XCTAssertEqual(anaPosts.items.count, 1)

        // An image can only be in one post, and only its owner can attach it.
        try await expectError(.POST, "v1/posts", token: ana.accessToken,
            body: CreatePostRequest(body: "Again", mediaIds: [photo.id]), status: .unprocessableEntity)
        let error = try await expectError(.POST, "v1/posts", token: leo.accessToken,
            body: CreatePostRequest(body: "Not mine", mediaIds: [photo.id]), status: .unprocessableEntity)
        XCTAssertEqual(error.fieldErrors?.map(\.field), ["mediaIds"])

        // Deleting the post deletes its images.
        try await expectStatus(.DELETE, "v1/posts/\(post.id)", token: ana.accessToken, status: .noContent)
        try await expectError(.GET, "v1/media/\(photo.id)", token: ana.accessToken, status: .notFound)
    }

    func testSharingRecipesLikesAndComments() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        var privateRecipe = Self.v60(beanID: bean.id)
        privateRecipe.visibility = .private
        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: privateRecipe)

        // Leo can't share Ana's recipe.
        let notMine = try await expectError(.POST, "v1/posts", token: leo.accessToken,
            body: CreatePostRequest(recipeId: recipe.id), status: .unprocessableEntity)
        XCTAssertEqual(notMine.fieldErrors?.map(\.field), ["recipeId"])

        let post: PostDTO = try await send(.POST, "v1/posts", token: ana.accessToken,
            body: CreatePostRequest(body: "  Morning cup  ", recipeId: recipe.id))
        XCTAssertEqual(post.kind, .recipe)
        XCTAssertEqual(post.body, "Morning cup")
        XCTAssertEqual(post.recipe?.id, recipe.id)
        // The post is public but the recipe is private: others see the post without it.
        let seenByLeo: PostDTO = try await send(.GET, "v1/posts/\(post.id)", token: leo.accessToken)
        XCTAssertNil(seenByLeo.recipe)

        let liked: LikeStateDTO = try await send(.PUT, "v1/posts/\(post.id)/like", token: leo.accessToken)
        XCTAssertEqual(liked, LikeStateDTO(isLiked: true, likeCount: 1))
        let likedAgain: LikeStateDTO = try await send(.PUT, "v1/posts/\(post.id)/like", token: leo.accessToken)
        XCTAssertEqual(likedAgain.likeCount, 1)

        let comment: CommentDTO = try await send(.POST, "v1/posts/\(post.id)/comments", token: leo.accessToken,
            body: CreateCommentRequest(body: "What grinder?"))
        let reply: CommentDTO = try await send(.POST, "v1/posts/\(post.id)/comments", token: ana.accessToken,
            body: CreateCommentRequest(body: "Comandante", parentId: comment.id))
        // Replies to replies stay one level deep.
        let nested: CommentDTO = try await send(.POST, "v1/posts/\(post.id)/comments", token: leo.accessToken,
            body: CreateCommentRequest(body: "Thanks!", parentId: reply.id))
        XCTAssertEqual(reply.parentId, comment.id)
        XCTAssertEqual(nested.parentId, comment.id)
        try await expectError(.POST, "v1/posts/\(post.id)/comments", token: leo.accessToken,
            body: CreateCommentRequest(body: "   "), status: .unprocessableEntity)

        let firstPage: BrewlyAPI.Page<CommentDTO> = try await send(
            .GET, "v1/posts/\(post.id)/comments?limit=2", token: ana.accessToken)
        XCTAssertEqual(firstPage.items.map(\.id), [comment.id, reply.id])
        XCTAssertTrue(firstPage.items.allSatisfy(\.canDelete))
        let cursor = try XCTUnwrap(firstPage.nextCursor)
        let secondPage: BrewlyAPI.Page<CommentDTO> = try await send(
            .GET, "v1/posts/\(post.id)/comments?limit=2&cursor=\(cursor)", token: ana.accessToken)
        XCTAssertEqual(secondPage.items.map(\.id), [nested.id])

        let withCounts: PostDTO = try await send(.GET, "v1/posts/\(post.id)", token: leo.accessToken)
        XCTAssertEqual(withCounts.likeCount, 1)
        XCTAssertEqual(withCounts.commentCount, 3)
        XCTAssertTrue(withCounts.isLiked)

        // Leo can't delete Ana's reply; Ana can delete any comment on her post, with its replies.
        try await expectError(.DELETE, "v1/comments/\(reply.id)", token: leo.accessToken, status: .notFound)
        try await expectStatus(.DELETE, "v1/comments/\(comment.id)", token: ana.accessToken, status: .noContent)
        let afterDelete: BrewlyAPI.Page<CommentDTO> = try await send(
            .GET, "v1/posts/\(post.id)/comments", token: ana.accessToken)
        XCTAssertTrue(afterDelete.items.isEmpty)

        let unliked: LikeStateDTO = try await send(.DELETE, "v1/posts/\(post.id)/like", token: leo.accessToken)
        XCTAssertEqual(unliked, LikeStateDTO(isLiked: false, likeCount: 0))
    }

    func testAvatar() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let first = try await upload(tinyJPEG(width: 400, height: 400), token: ana.accessToken)
        let updated: CurrentUserDTO = try await send(.PUT, "v1/me/avatar", token: ana.accessToken,
            body: UpdateAvatarRequest(mediaId: first.id))
        XCTAssertEqual(updated.avatarURL, first.url)
        // Avatars are visible to everyone.
        try await expectStatus(.GET, "v1/media/\(first.id)", token: leo.accessToken, status: .ok)

        // Replacing the avatar deletes the previous image; others' images can't be used.
        let second = try await upload(tinyJPEG(width: 400, height: 400), token: ana.accessToken)
        let _: CurrentUserDTO = try await send(.PUT, "v1/me/avatar", token: ana.accessToken,
            body: UpdateAvatarRequest(mediaId: second.id))
        try await expectError(.GET, "v1/media/\(first.id)", token: ana.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/me/avatar", token: leo.accessToken,
            body: UpdateAvatarRequest(mediaId: second.id), status: .unprocessableEntity)

        let removed: CurrentUserDTO = try await send(.DELETE, "v1/me/avatar", token: ana.accessToken)
        XCTAssertNil(removed.avatarURL)
    }

    func testUploadsMustBeJPEG() async throws {
        let ana = try await register("ana.barista")
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: ana.accessToken)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: [0x89, 0x50, 0x4E, 0x47])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unprocessableEntity)
        })
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: ana.accessToken)
            req.headers.contentType = .png
            req.body = ByteBuffer(bytes: Array(tinyJPEG(width: 10, height: 10)))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unsupportedMediaType)
        })
    }

    // MARK: - Notifications

    func testNotificationsForSocialActions() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let leoBean: BeanDTO = try await send(.POST, "v1/beans", token: leo.accessToken, body: Self.geisha)
        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))
        let post: PostDTO = try await send(.POST, "v1/posts", token: ana.accessToken,
            body: CreatePostRequest(body: "Morning V60", recipeId: recipe.id))

        // Follow, like and save; undoing and redoing a like notifies once.
        let _: FollowStateDTO = try await send(.PUT, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)
        let _: LikeStateDTO = try await send(.PUT, "v1/posts/\(post.id)/like", token: leo.accessToken)
        let _: LikeStateDTO = try await send(.DELETE, "v1/posts/\(post.id)/like", token: leo.accessToken)
        let _: LikeStateDTO = try await send(.PUT, "v1/posts/\(post.id)/like", token: leo.accessToken)
        let _: SaveStateDTO = try await send(.PUT, "v1/recipes/\(recipe.id)/save", token: leo.accessToken)
        // Ana's own like and comment don't notify her.
        let _: LikeStateDTO = try await send(.PUT, "v1/posts/\(post.id)/like", token: ana.accessToken)
        let question: CommentDTO = try await send(.POST, "v1/posts/\(post.id)/comments", token: leo.accessToken,
            body: CreateCommentRequest(body: "What grinder?"))
        let _: CommentDTO = try await send(.POST, "v1/posts/\(post.id)/comments", token: ana.accessToken,
            body: CreateCommentRequest(body: "Comandante", parentId: question.id))
        var remix = Self.v60(beanID: leoBean.id)
        remix.forkedFromId = recipe.id
        let remixed: RecipeDTO = try await send(.POST, "v1/recipes", token: leo.accessToken, body: remix)

        let unread: UnreadCountDTO = try await send(.GET, "v1/me/notifications/unread-count", token: ana.accessToken)
        XCTAssertEqual(unread.count, 5)
        let anaInbox: BrewlyAPI.Page<NotificationDTO> = try await send(.GET, "v1/me/notifications", token: ana.accessToken)
        XCTAssertEqual(anaInbox.items.map(\.kind), [.recipeFork, .comment, .recipeSave, .postLike, .follow])
        XCTAssertTrue(anaInbox.items.allSatisfy { $0.actor.id == leo.user.id && !$0.isRead })
        XCTAssertEqual(anaInbox.items.first?.recipeId, remixed.id)
        XCTAssertEqual(anaInbox.items[1].commentExcerpt, "What grinder?")
        XCTAssertEqual(anaInbox.items[1].postExcerpt, "Morning V60")

        // Leo gets the reply to his comment.
        let leoInbox: BrewlyAPI.Page<NotificationDTO> = try await send(.GET, "v1/me/notifications", token: leo.accessToken)
        XCTAssertEqual(leoInbox.items.map(\.kind), [.commentReply])

        try await expectStatus(.POST, "v1/me/notifications/read", token: ana.accessToken, status: .noContent)
        let afterRead: UnreadCountDTO = try await send(.GET, "v1/me/notifications/unread-count", token: ana.accessToken)
        XCTAssertEqual(afterRead.count, 0)

        // Undoing a follow removes its notification.
        let _: FollowStateDTO = try await send(.DELETE, "v1/users/\(ana.user.id)/follow", token: leo.accessToken)
        let final: BrewlyAPI.Page<NotificationDTO> = try await send(.GET, "v1/me/notifications?limit=2", token: ana.accessToken)
        XCTAssertEqual(final.items.map(\.kind), [.recipeFork, .comment])
        let cursor = try XCTUnwrap(final.nextCursor)
        let rest: BrewlyAPI.Page<NotificationDTO> = try await send(
            .GET, "v1/me/notifications?limit=2&cursor=\(cursor)", token: ana.accessToken)
        XCTAssertEqual(rest.items.map(\.kind), [.recipeSave, .postLike])
    }

    func testPrivateRemixesAndBlockedMembersDontNotify() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let leoBean: BeanDTO = try await send(.POST, "v1/beans", token: leo.accessToken, body: Self.geisha)
        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        var remix = Self.v60(beanID: leoBean.id)
        remix.forkedFromId = recipe.id
        remix.visibility = .private
        let _: RecipeDTO = try await send(.POST, "v1/recipes", token: leo.accessToken, body: remix)
        let _: SaveStateDTO = try await send(.PUT, "v1/recipes/\(recipe.id)/save", token: leo.accessToken)

        // After a block, the existing notification is hidden.
        try await app.db.sql.raw("""
            INSERT INTO user_blocks (blocker_id, blocked_id) VALUES (\(bind: ana.user.id), \(bind: leo.user.id))
            """).run()
        let inbox: BrewlyAPI.Page<NotificationDTO> = try await send(.GET, "v1/me/notifications", token: ana.accessToken)
        XCTAssertTrue(inbox.items.isEmpty)
        let unread: UnreadCountDTO = try await send(.GET, "v1/me/notifications/unread-count", token: ana.accessToken)
        XCTAssertEqual(unread.count, 0)
    }

    // MARK: - Fixtures

    private static let geisha = UpsertBeanRequest(
        name: "Geisha Washed",
        roaster: "Demo Roasters",
        countryCode: "CO",
        farm: "Finca Las Nubes",
        altitudeMinM: 1750,
        altitudeMaxM: 1900,
        processingMethodSlug: "washed",
        varietalSlugs: ["geisha"],
        flavorNoteSlugs: ["jasmine"],
        roastLevel: .light,
        roastDate: CalendarDate(year: 2026, month: 9, day: 1)
    )

    private static func v60(beanID: UUID) -> UpsertRecipeRequest {
        UpsertRecipeRequest(
            beanId: beanID,
            methodSlug: "v60",
            title: "Floral V60",
            doseG: 15,
            waterG: 250,
            yieldG: 215,
            grindSize: .mediumFine,
            grinderSlug: "comandante_c40_mk4",
            grindSetting: "24 clicks",
            waterTempC: 93,
            bloomWaterG: 45,
            bloomTimeS: 45,
            totalTimeS: 180,
            filterType: .paper,
            tdsPercent: 1.38,
            rating: 5,
            flavorNoteSlugs: ["jasmine", "peach"],
            steps: [
                RecipeStepInput(kind: .bloom, startS: 0, waterTargetG: 45, instruction: "Bloom"),
                RecipeStepInput(kind: .pour, startS: 45, waterTargetG: 250),
            ]
        )
    }

    // MARK: - HTTP helpers

    private struct Empty: Encodable {}

    private func register(_ username: String) async throws -> AuthResponse {
        try await send(.POST, "v1/auth/register", body: RegisterRequest(
            email: "\(username)@example.com", password: "test-password", username: username, displayName: username
        ))
    }

    private func upload(_ jpeg: Data, token: String, file: StaticString = #filePath, line: UInt = #line) async throws -> MediaDTO {
        var media: MediaDTO?
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: Array(jpeg))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created, res.body.string, file: file, line: line)
            media = try res.content.decode(MediaDTO.self, using: BrewlyJSON.makeDecoder())
        })
        return try XCTUnwrap(media, file: file, line: line)
    }

    private func send<Output: Decodable>(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        body: (some Encodable)? = Empty?.none,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> Output {
        var decoded: Output?
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: body)
        }, afterResponse: { res in
            XCTAssertLessThan(res.status.code, 300, "\(method) \(path): \(res.body.string)", file: file, line: line)
            decoded = try res.content.decode(Output.self, using: BrewlyJSON.makeDecoder())
        })
        return try XCTUnwrap(decoded, file: file, line: line)
    }

    private func expectStatus(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        status: HTTPResponseStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: Empty?.none)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, status, res.body.string, file: file, line: line)
        })
    }

    @discardableResult
    private func expectError(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        body: (some Encodable)? = Empty?.none,
        status: HTTPResponseStatus,
        code: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> APIErrorResponse {
        var decoded: APIErrorResponse?
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: body)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, status, res.body.string, file: file, line: line)
            decoded = try res.content.decode(APIErrorResponse.self, using: BrewlyJSON.makeDecoder())
        })
        let error = try XCTUnwrap(decoded, file: file, line: line)
        if let code {
            XCTAssertEqual(error.code, code, file: file, line: line)
        }
        return error
    }

    private static func prepare(_ req: inout XCTHTTPRequest, token: String?, body: (some Encodable)?) throws {
        if let token {
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }
        if let body {
            try req.content.encode(body, using: BrewlyJSON.makeEncoder())
        }
    }
}
