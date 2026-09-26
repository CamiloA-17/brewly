import BrewlyAPI
import Foundation

/// Every endpoint of the Brewly API v1.
public enum Endpoints {
    // MARK: Auth

    public static func register(_ body: RegisterRequest) -> Endpoint<AuthResponse> {
        Endpoint(.post, "v1/auth/register", body: body, requiresAuth: false)
    }

    public static func login(_ body: LoginRequest) -> Endpoint<AuthResponse> {
        Endpoint(.post, "v1/auth/login", body: body, requiresAuth: false)
    }

    public static func refresh(_ body: RefreshTokenRequest) -> Endpoint<AuthResponse> {
        Endpoint(.post, "v1/auth/refresh", body: body, requiresAuth: false)
    }

    public static func logout(_ body: RefreshTokenRequest) -> Endpoint<EmptyResponse> {
        Endpoint(.post, "v1/auth/logout", body: body, requiresAuth: false)
    }

    // MARK: Me

    public static let me = Endpoint<CurrentUserDTO>(.get, "v1/me")

    public static func updateMe(_ body: UpdateProfileRequest) -> Endpoint<CurrentUserDTO> {
        Endpoint(.patch, "v1/me", body: body)
    }

    public static func completeOnboarding(_ body: CompleteOnboardingRequest) -> Endpoint<CurrentUserDTO> {
        Endpoint(.put, "v1/me/onboarding", body: body)
    }

    public static let deleteMe = Endpoint<EmptyResponse>(.delete, "v1/me")

    public static let myMethods = Endpoint<UserMethodsDTO>(.get, "v1/me/methods")

    public static func addMyMethod(slug: String) -> Endpoint<EmptyResponse> {
        Endpoint(.put, "v1/me/methods/\(slug)")
    }

    public static func removeMyMethod(slug: String) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/me/methods/\(slug)")
    }

    // MARK: Catalog

    public static let catalog = Endpoint<CatalogDTO>(.get, "v1/catalog")

    // MARK: Beans

    public static func myBeans(includeArchived: Bool) -> Endpoint<[BeanDTO]> {
        Endpoint(.get, "v1/me/beans", queryItems: [URLQueryItem(name: "includeArchived", value: String(includeArchived))])
    }

    public static func bean(id: UUID) -> Endpoint<BeanDTO> {
        Endpoint(.get, "v1/beans/\(id.uuidString)")
    }

    public static func createBean(_ body: UpsertBeanRequest) -> Endpoint<BeanDTO> {
        Endpoint(.post, "v1/beans", body: body)
    }

    public static func updateBean(id: UUID, _ body: UpsertBeanRequest) -> Endpoint<BeanDTO> {
        Endpoint(.put, "v1/beans/\(id.uuidString)", body: body)
    }

    public static func deleteBean(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/beans/\(id.uuidString)")
    }

    // MARK: Equipment

    public static let myEquipment = Endpoint<[EquipmentDTO]>(.get, "v1/me/equipment")

    public static func memberEquipment(id: UUID) -> Endpoint<[EquipmentDTO]> {
        Endpoint(.get, "v1/users/\(id.uuidString)/equipment")
    }

    public static func createEquipment(_ body: UpsertEquipmentRequest) -> Endpoint<EquipmentDTO> {
        Endpoint(.post, "v1/me/equipment", body: body)
    }

    public static func updateEquipment(id: UUID, _ body: UpsertEquipmentRequest) -> Endpoint<EquipmentDTO> {
        Endpoint(.put, "v1/me/equipment/\(id.uuidString)", body: body)
    }

    public static func deleteEquipment(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/me/equipment/\(id.uuidString)")
    }

    // MARK: Recipes

    public static func myRecipes(cursor: String?) -> Endpoint<Page<RecipeSummaryDTO>> {
        Endpoint(.get, "v1/me/recipes", queryItems: queryItems(["cursor": cursor]))
    }

    public static func exploreRecipes(
        methodSlug: String?,
        countryCode: String?,
        varietalSlug: String?,
        cursor: String?
    ) -> Endpoint<Page<RecipeSummaryDTO>> {
        Endpoint(.get, "v1/recipes", queryItems: queryItems([
            "method": methodSlug, "country": countryCode, "varietal": varietalSlug, "cursor": cursor,
        ]))
    }

    public static func recipe(id: UUID) -> Endpoint<RecipeDTO> {
        Endpoint(.get, "v1/recipes/\(id.uuidString)")
    }

    public static func createRecipe(_ body: UpsertRecipeRequest) -> Endpoint<RecipeDTO> {
        Endpoint(.post, "v1/recipes", body: body)
    }

    public static func updateRecipe(id: UUID, _ body: UpsertRecipeRequest) -> Endpoint<RecipeDTO> {
        Endpoint(.put, "v1/recipes/\(id.uuidString)", body: body)
    }

    public static func deleteRecipe(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/recipes/\(id.uuidString)")
    }

    public static func savedRecipes(cursor: String?) -> Endpoint<Page<RecipeSummaryDTO>> {
        Endpoint(.get, "v1/me/saved-recipes", queryItems: queryItems(["cursor": cursor]))
    }

    public static func saveRecipe(id: UUID) -> Endpoint<SaveStateDTO> {
        Endpoint(.put, "v1/recipes/\(id.uuidString)/save")
    }

    public static func unsaveRecipe(id: UUID) -> Endpoint<SaveStateDTO> {
        Endpoint(.delete, "v1/recipes/\(id.uuidString)/save")
    }

    // MARK: Media

    public static func uploadImage(jpeg: Data) -> Endpoint<MediaDTO> {
        Endpoint(.post, "v1/media", rawBody: RawBody(data: jpeg, contentType: "image/jpeg"))
    }

    /// `path` is the server's media URL without the leading slash, e.g. `v1/media/<id>`.
    public static func image(path: String) -> Endpoint<Data> {
        Endpoint(.get, path)
    }

    public static func setAvatar(mediaID: UUID) -> Endpoint<CurrentUserDTO> {
        Endpoint(.put, "v1/me/avatar", body: UpdateAvatarRequest(mediaId: mediaID))
    }

    public static let removeAvatar = Endpoint<CurrentUserDTO>(.delete, "v1/me/avatar")

    // MARK: Posts

    public static func feed(cursor: String?) -> Endpoint<Page<PostDTO>> {
        Endpoint(.get, "v1/feed", queryItems: queryItems(["cursor": cursor]))
    }

    public static func explorePosts(cursor: String?) -> Endpoint<Page<PostDTO>> {
        Endpoint(.get, "v1/posts/explore", queryItems: queryItems(["cursor": cursor]))
    }

    public static func userPosts(id: UUID, cursor: String?) -> Endpoint<Page<PostDTO>> {
        Endpoint(.get, "v1/users/\(id.uuidString)/posts", queryItems: queryItems(["cursor": cursor]))
    }

    public static func post(id: UUID) -> Endpoint<PostDTO> {
        Endpoint(.get, "v1/posts/\(id.uuidString)")
    }

    public static func createPost(_ body: CreatePostRequest) -> Endpoint<PostDTO> {
        Endpoint(.post, "v1/posts", body: body)
    }

    public static func deletePost(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/posts/\(id.uuidString)")
    }

    public static func likePost(id: UUID) -> Endpoint<LikeStateDTO> {
        Endpoint(.put, "v1/posts/\(id.uuidString)/like")
    }

    public static func unlikePost(id: UUID) -> Endpoint<LikeStateDTO> {
        Endpoint(.delete, "v1/posts/\(id.uuidString)/like")
    }

    public static func comments(postID: UUID, cursor: String?) -> Endpoint<Page<CommentDTO>> {
        Endpoint(.get, "v1/posts/\(postID.uuidString)/comments", queryItems: queryItems(["cursor": cursor, "limit": "50"]))
    }

    public static func addComment(postID: UUID, _ body: CreateCommentRequest) -> Endpoint<CommentDTO> {
        Endpoint(.post, "v1/posts/\(postID.uuidString)/comments", body: body)
    }

    public static func deleteComment(id: UUID) -> Endpoint<EmptyResponse> {
        Endpoint(.delete, "v1/comments/\(id.uuidString)")
    }

    // MARK: Notifications

    public static func notifications(cursor: String?) -> Endpoint<Page<NotificationDTO>> {
        Endpoint(.get, "v1/me/notifications", queryItems: queryItems(["cursor": cursor]))
    }

    public static let unreadNotificationCount = Endpoint<UnreadCountDTO>(.get, "v1/me/notifications/unread-count")

    public static let markNotificationsRead = Endpoint<EmptyResponse>(.post, "v1/me/notifications/read")

    // MARK: People

    public static func searchUsers(query: String) -> Endpoint<[UserSummaryDTO]> {
        Endpoint(.get, "v1/users", queryItems: queryItems(["q": query]))
    }

    public static func userProfile(id: UUID) -> Endpoint<UserProfileDTO> {
        Endpoint(.get, "v1/users/\(id.uuidString)")
    }

    public static func userRecipes(id: UUID, cursor: String?) -> Endpoint<Page<RecipeSummaryDTO>> {
        Endpoint(.get, "v1/users/\(id.uuidString)/recipes", queryItems: queryItems(["cursor": cursor]))
    }

    public static func followers(of id: UUID, cursor: String?) -> Endpoint<Page<UserSummaryDTO>> {
        Endpoint(.get, "v1/users/\(id.uuidString)/followers", queryItems: queryItems(["cursor": cursor]))
    }

    public static func following(of id: UUID, cursor: String?) -> Endpoint<Page<UserSummaryDTO>> {
        Endpoint(.get, "v1/users/\(id.uuidString)/following", queryItems: queryItems(["cursor": cursor]))
    }

    public static func follow(id: UUID) -> Endpoint<FollowStateDTO> {
        Endpoint(.put, "v1/users/\(id.uuidString)/follow")
    }

    public static func unfollow(id: UUID) -> Endpoint<FollowStateDTO> {
        Endpoint(.delete, "v1/users/\(id.uuidString)/follow")
    }

    private static func queryItems(_ values: KeyValuePairs<String, String?>) -> [URLQueryItem] {
        values.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
    }
}
