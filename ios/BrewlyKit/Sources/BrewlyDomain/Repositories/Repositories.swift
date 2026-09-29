import Foundation

/// Authentication and session lifecycle.
public protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws -> UserProfile
    func signUp(_ account: NewAccount) async throws -> UserProfile
    func signOut() async
    /// Whether credentials from a previous launch are stored.
    func hasStoredSession() async -> Bool
}

public protocol ProfileRepository: Sendable {
    func currentUser() async throws -> UserProfile
    func updateProfile(_ changes: ProfileChanges) async throws -> UserProfile
    /// Stores the private details of an account that does not have them yet.
    func completeOnboarding(_ details: PersonalDetails) async throws -> UserProfile
    /// Uploads a picked image (resized before sending) and uses it as the profile picture.
    func updateAvatar(imageData: Data) async throws -> UserProfile
    func removeAvatar() async throws -> UserProfile
    /// Permanently deletes the account and everything it owns.
    func deleteAccount() async throws
}

/// The signed-in user's gear, and other members' (public on their profile).
public protocol EquipmentRepository: Sendable {
    func myEquipment() async throws -> [Equipment]
    func equipment(ofMember memberID: UUID) async throws -> [Equipment]
    /// Creates the item when `id` is `nil`, otherwise replaces it.
    func save(_ draft: EquipmentDraft, id: UUID?) async throws -> Equipment
    func delete(id: UUID) async throws
}

public protocol CatalogRepository: Sendable {
    /// The global catalogs, cached after the first successful load.
    func catalog(forceRefresh: Bool) async throws -> Catalog
}

extension CatalogRepository {
    public func catalog() async throws -> Catalog {
        try await catalog(forceRefresh: false)
    }
}

/// Brew methods from the global catalog that the user owns or uses.
public protocol UserMethodsRepository: Sendable {
    func myMethodSlugs() async throws -> Set<String>
    func setUsing(_ isUsing: Bool, methodSlug: String) async throws
}

public protocol BeanRepository: Sendable {
    func myBeans(includeArchived: Bool) async throws -> [Bean]
    func bean(id: UUID) async throws -> Bean
    func create(_ draft: BeanDraft) async throws -> Bean
    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean
    func delete(id: UUID) async throws
}

public protocol RecipeRepository: Sendable {
    func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary>
    func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary>
    func recipe(id: UUID) async throws -> Recipe
    func create(_ input: RecipeInput) async throws -> Recipe
    func update(id: UUID, _ input: RecipeInput) async throws -> Recipe
    func delete(id: UUID) async throws
}

/// The brew journal.
public protocol BrewLogRepository: Sendable {
    func myBrews(filter: BrewLogFilter, cursor: String?) async throws -> PagedResult<BrewLog>
    func brew(id: UUID) async throws -> BrewLog
    /// Uploads `draft.newPhotoData` if any, then creates the brew (or replaces it when `id` is given).
    func save(_ draft: BrewLogDraft, beanID: UUID, methodSlug: String, id: UUID?) async throws -> BrewLog
    func delete(id: UUID) async throws
}

/// Recipes the signed-in user saved to brew later.
public protocol RecipeSavesRepository: Sendable {
    func savedRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary>
    func save(recipeID: UUID) async throws -> SaveState
    func unsave(recipeID: UUID) async throws -> SaveState
}

/// Other members: search, profiles, their recipes and the follow graph.
public protocol PeopleRepository: Sendable {
    /// Members whose username or name starts with `query`.
    func search(_ query: String) async throws -> [UserSummary]
    func profile(id: UUID) async throws -> MemberProfile
    func recipes(of memberID: UUID, cursor: String?) async throws -> PagedResult<RecipeSummary>
    func followers(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary>
    func following(of memberID: UUID, cursor: String?) async throws -> PagedResult<UserSummary>
    func follow(_ memberID: UUID) async throws -> FollowState
    func unfollow(_ memberID: UUID) async throws -> FollowState
}

/// Posts, the home feed, likes and comments.
public protocol PostRepository: Sendable {
    /// The user's posts and those of the people they follow.
    func feed(cursor: String?) async throws -> PagedResult<Post>
    /// Public posts of the community.
    func explore(cursor: String?) async throws -> PagedResult<Post>
    func posts(of memberID: UUID, cursor: String?) async throws -> PagedResult<Post>
    func post(id: UUID) async throws -> Post
    /// Uploads the draft's photos, then publishes the post.
    func create(_ draft: PostDraft) async throws -> Post
    func delete(id: UUID) async throws
    func like(postID: UUID) async throws -> LikeState
    func unlike(postID: UUID) async throws -> LikeState
    /// Comments oldest first.
    func comments(postID: UUID, cursor: String?) async throws -> PagedResult<PostComment>
    func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> PostComment
    func deleteComment(id: UUID) async throws
}

/// Loads images from the API, which requires the access token.
public protocol ImageLoader: Sendable {
    func imageData(for url: URL) async throws -> Data
}

/// The signed-in user's notifications.
public protocol NotificationRepository: Sendable {
    /// Newest first.
    func notifications(cursor: String?) async throws -> PagedResult<AppNotification>
    func unreadCount() async throws -> Int
    func markAllRead() async throws
}
