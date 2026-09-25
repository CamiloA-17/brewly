import Foundation

/// Authentication and session lifecycle.
public protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws -> UserProfile
    func signUp(email: String, password: String, username: String, displayName: String) async throws -> UserProfile
    func signOut() async
    /// Whether credentials from a previous launch are stored.
    func hasStoredSession() async -> Bool
}

public protocol ProfileRepository: Sendable {
    func currentUser() async throws -> UserProfile
    func updateProfile(displayName: String, bio: String?, location: String?) async throws -> UserProfile
    /// Permanently deletes the account and everything it owns.
    func deleteAccount() async throws
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
