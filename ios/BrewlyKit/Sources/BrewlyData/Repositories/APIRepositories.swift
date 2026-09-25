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

    public func signUp(email: String, password: String, username: String, displayName: String) async throws -> UserProfile {
        try await mappingErrors {
            let auth = try await publicClient.send(Endpoints.register(RegisterRequest(
                email: email, password: password, username: username, displayName: displayName
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

    public func updateProfile(displayName: String, bio: String?, location: String?) async throws -> UserProfile {
        try await mappingErrors {
            let request = UpdateProfileRequest(displayName: displayName, bio: bio, location: location)
            return UserProfile(try await client.send(Endpoints.updateMe(request)))
        }
    }

    public func deleteAccount() async throws {
        try await mappingErrors { _ = try await client.send(Endpoints.deleteMe) }
        await session.discard()
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
