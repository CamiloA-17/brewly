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
