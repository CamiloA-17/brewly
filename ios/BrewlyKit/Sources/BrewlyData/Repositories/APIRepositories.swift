import BrewlyAPI
import BrewlyDomain
import BrewlyNetworking
import Foundation

public struct APIAuthRepository: AuthRepository {
    private let publicClient: APIClient
    private let session: SessionManager

    /// - Parameter publicClient: a client without a token provider.
    public init(publicClient: APIClient, session: SessionManager) {
        self.publicClient = publicClient
        self.session = session
    }

    public func signIn(email: String, password: String) async throws -> UserProfile {
        try await mappingErrors {
            let auth = try await publicClient.send(Endpoints.login(LoginRequest(email: email, password: password)))
            await session.start(with: auth)
            return UserProfile(auth.user)
        }
    }

    public func signUp(_ account: NewAccount) async throws -> UserProfile {
        try await mappingErrors {
            let auth = try await publicClient.send(Endpoints.register(RegisterRequest(
                email: account.email, password: account.password, username: account.username,
                firstName: account.firstName, lastName: account.lastName, birthDate: account.birthDate,
                acceptedTerms: account.acceptedTerms
            )))
            await session.start(with: auth)
            return UserProfile(auth.user)
        }
    }

    public func signOut() async {
        await session.end()
    }

    public func hasStoredSession() async -> Bool {
        await session.hasSession
    }
}

public struct APIProfileRepository: ProfileRepository {
    private let client: APIClient
    private let session: SessionManager

    public init(client: APIClient, session: SessionManager) {
        self.client = client
        self.session = session
    }

    public func currentUser() async throws -> UserProfile {
        try await mappingErrors { UserProfile(try await client.send(Endpoints.me)) }
    }

    public func updateProfile(_ changes: ProfileChanges) async throws -> UserProfile {
        try await mappingErrors {
            let request = UpdateProfileRequest(
                displayName: changes.displayName, firstName: changes.firstName, lastName: changes.lastName,
                birthDate: changes.birthDate, bio: changes.bio, countryCode: changes.countryCode, city: changes.city
            )
            return UserProfile(try await client.send(Endpoints.updateMe(request)))
        }
    }

    public func completeOnboarding(_ details: PersonalDetails) async throws -> UserProfile {
        try await mappingErrors {
            let request = CompleteOnboardingRequest(
                firstName: details.firstName, lastName: details.lastName, birthDate: details.birthDate,
                acceptedTerms: details.acceptedTerms
            )
            return UserProfile(try await client.send(Endpoints.completeOnboarding(request)))
        }
    }

    public func deleteAccount() async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteMe) }
        await session.discard()
    }

    public func updateAvatar(imageData: Data) async throws -> UserProfile {
        try await mappingErrors {
            let media = try await APIPostRepository.upload(imageData, client: client)
            return UserProfile(try await client.send(Endpoints.setAvatar(mediaID: media.id)))
        }
    }

    public func removeAvatar() async throws -> UserProfile {
        try await mappingErrors { UserProfile(try await client.send(Endpoints.removeAvatar)) }
    }
}

/// Loads the catalogs once and keeps them in memory.
public actor APICatalogRepository: CatalogRepository {
    private let client: APIClient
    private var cached: Catalog?

    public init(client: APIClient) {
        self.client = client
    }

    public func catalog(forceRefresh: Bool) async throws -> Catalog {
        if let cached, !forceRefresh { return cached }
        let catalog = try await mappingErrors { Catalog(try await client.send(Endpoints.catalog)) }
        cached = catalog
        return catalog
    }
}

public struct APIUserMethodsRepository: UserMethodsRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func myMethodSlugs() async throws -> Set<String> {
        try await mappingErrors { Set(try await client.send(Endpoints.myMethods).methodSlugs) }
    }

    public func setUsing(_ isUsing: Bool, methodSlug: String) async throws {
        try await mappingErrors {
            _ = try await client.send(isUsing ? Endpoints.addMyMethod(slug: methodSlug) : Endpoints.removeMyMethod(slug: methodSlug))
        }
    }
}

public struct APIBeanRepository: BeanRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func myBeans(includeArchived: Bool) async throws -> [Bean] {
        try await mappingErrors { try await client.send(Endpoints.myBeans(includeArchived: includeArchived)).map(Bean.init) }
    }

    public func bean(id: UUID) async throws -> Bean {
        try await mappingErrors { Bean(try await client.send(Endpoints.bean(id: id))) }
    }

    public func create(_ draft: BeanDraft) async throws -> Bean {
        try await mappingErrors { Bean(try await client.send(Endpoints.createBean(UpsertBeanRequest(draft)))) }
    }

    public func update(id: UUID, _ draft: BeanDraft) async throws -> Bean {
        try await mappingErrors { Bean(try await client.send(Endpoints.updateBean(id: id, UpsertBeanRequest(draft)))) }
    }

    public func delete(id: UUID) async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteBean(id: id)) }
    }
}

public struct APIEquipmentRepository: EquipmentRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func myEquipment() async throws -> [Equipment] {
        try await mappingErrors { try await client.send(Endpoints.myEquipment).map(Equipment.init) }
    }

    public func equipment(ofMember memberID: UUID) async throws -> [Equipment] {
        try await mappingErrors { try await client.send(Endpoints.memberEquipment(id: memberID)).map(Equipment.init) }
    }

    public func save(_ draft: EquipmentDraft, id: UUID?) async throws -> Equipment {
        try await mappingErrors {
            let request = UpsertEquipmentRequest(draft)
            if let id {
                return Equipment(try await client.send(Endpoints.updateEquipment(id: id, request)))
            }
            return Equipment(try await client.send(Endpoints.createEquipment(request)))
        }
    }

    public func delete(id: UUID) async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteEquipment(id: id)) }
    }
}

public struct APIRecipeRepository: RecipeRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.myRecipes(cursor: cursor))
            return PagedResult(items: page.items.map(RecipeSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.exploreRecipes(
                methodSlug: filter.methodSlug,
                countryCode: filter.countryCode,
                varietalSlug: filter.varietalSlug,
                cursor: cursor
            ))
            return PagedResult(items: page.items.map(RecipeSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func recipe(id: UUID) async throws -> Recipe {
        try await mappingErrors { Recipe(try await client.send(Endpoints.recipe(id: id))) }
    }

    public func create(_ input: RecipeInput) async throws -> Recipe {
        try await mappingErrors { Recipe(try await client.send(Endpoints.createRecipe(UpsertRecipeRequest(input)))) }
    }

    public func update(id: UUID, _ input: RecipeInput) async throws -> Recipe {
        try await mappingErrors { Recipe(try await client.send(Endpoints.updateRecipe(id: id, UpsertRecipeRequest(input)))) }
    }

    public func delete(id: UUID) async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteRecipe(id: id)) }
    }
}

extension APIRecipeRepository: RecipeSavesRepository {
    public func savedRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.savedRecipes(cursor: cursor))
            return PagedResult(items: page.items.map(RecipeSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func save(recipeID: UUID) async throws -> SaveState {
        try await mappingErrors { SaveState(try await client.send(Endpoints.saveRecipe(id: recipeID))) }
    }

    public func unsave(recipeID: UUID) async throws -> SaveState {
        try await mappingErrors { SaveState(try await client.send(Endpoints.unsaveRecipe(id: recipeID))) }
    }
}

public struct APIPeopleRepository: PeopleRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func search(_ query: String) async throws -> [UserSummary] {
        try await mappingErrors { try await client.send(Endpoints.searchUsers(query: query)).map(UserSummary.init) }
    }

    public func profile(id: UUID) async throws -> MemberProfile {
        try await mappingErrors { MemberProfile(try await client.send(Endpoints.userProfile(id: id))) }
    }

    public func recipes(of memberID: UUID, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.userRecipes(id: memberID, cursor: cursor))
            return PagedResult(items: page.items.map(RecipeSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func followers(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.followers(of: memberID, cursor: cursor))
            return PagedResult(items: page.items.map(UserSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func following(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.following(of: memberID, cursor: cursor))
            return PagedResult(items: page.items.map(UserSummary.init), nextCursor: page.nextCursor)
        }
    }

    public func follow(_ memberID: UUID) async throws -> FollowState {
        try await mappingErrors { FollowState(try await client.send(Endpoints.follow(id: memberID))) }
    }

    public func unfollow(_ memberID: UUID) async throws -> FollowState {
        try await mappingErrors { FollowState(try await client.send(Endpoints.unfollow(id: memberID))) }
    }
}

public struct APIPostRepository: PostRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func feed(cursor: String?) async throws -> PagedResult<Post> {
        try await page(Endpoints.feed(cursor: cursor))
    }

    public func explore(cursor: String?) async throws -> PagedResult<Post> {
        try await page(Endpoints.explorePosts(cursor: cursor))
    }

    public func posts(of memberID: UUID, cursor: String?) async throws -> PagedResult<Post> {
        try await page(Endpoints.userPosts(id: memberID, cursor: cursor))
    }

    public func post(id: UUID) async throws -> Post {
        try await mappingErrors { Post(try await client.send(Endpoints.post(id: id))) }
    }

    public func create(_ draft: PostDraft) async throws -> Post {
        try await mappingErrors {
            var mediaIDs: [UUID] = []
            for photo in draft.photos {
                mediaIDs.append(try await Self.upload(photo, client: client).id)
            }
            let request = CreatePostRequest(
                body: draft.body.nilIfBlank,
                recipeId: draft.recipeID,
                beanId: draft.beanID,
                mediaIds: mediaIDs,
                visibility: draft.visibility
            )
            return Post(try await client.send(Endpoints.createPost(request)))
        }
    }

    public func delete(id: UUID) async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deletePost(id: id)) }
    }

    public func like(postID: UUID) async throws -> LikeState {
        try await mappingErrors { LikeState(try await client.send(Endpoints.likePost(id: postID))) }
    }

    public func unlike(postID: UUID) async throws -> LikeState {
        try await mappingErrors { LikeState(try await client.send(Endpoints.unlikePost(id: postID))) }
    }

    public func comments(postID: UUID, cursor: String?) async throws -> PagedResult<PostComment> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.comments(postID: postID, cursor: cursor))
            return PagedResult(items: page.items.map(PostComment.init), nextCursor: page.nextCursor)
        }
    }

    public func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> PostComment {
        try await mappingErrors {
            PostComment(try await client.send(Endpoints.addComment(
                postID: postID, CreateCommentRequest(body: body, parentId: parentID)
            )))
        }
    }

    public func deleteComment(id: UUID) async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteComment(id: id)) }
    }

    /// Resizes a picked image and uploads it.
    static func upload(_ imageData: Data, client: APIClient) async throws -> MediaDTO {
        guard let jpeg = ImageCompressor.jpeg(from: imageData) else {
            throw DomainError.validation([RuleViolation(field: "photos", kind: .invalidFormat)])
        }
        return try await client.send(Endpoints.uploadImage(jpeg: jpeg))
    }

    private func page(_ endpoint: Endpoint<Page<PostDTO>>) async throws -> PagedResult<Post> {
        try await mappingErrors {
            let page = try await client.send(endpoint)
            return PagedResult(items: page.items.map(Post.init), nextCursor: page.nextCursor)
        }
    }
}

public struct APINotificationRepository: NotificationRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func notifications(cursor: String?) async throws -> PagedResult<AppNotification> {
        try await mappingErrors {
            let page = try await client.send(Endpoints.notifications(cursor: cursor))
            return PagedResult(items: page.items.map(AppNotification.init), nextCursor: page.nextCursor)
        }
    }

    public func unreadCount() async throws -> Int {
        try await mappingErrors { try await client.send(Endpoints.unreadNotificationCount).count }
    }

    public func markAllRead() async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.markNotificationsRead) }
    }
}
