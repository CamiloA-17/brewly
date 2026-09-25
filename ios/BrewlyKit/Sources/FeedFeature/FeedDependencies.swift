import BrewlyDomain
import Foundation

public struct FeedDependencies: Sendable {
    public var posts: any PostRepository
    /// The user's recipes and beans, to share them in a post.
    public var recipes: any RecipeRepository
    public var beans: any BeanRepository
    public var catalog: any CatalogRepository
    /// The signed-in user, to know which posts can be deleted.
    public var currentUserID: UUID

    public init(
        posts: any PostRepository,
        recipes: any RecipeRepository,
        beans: any BeanRepository,
        catalog: any CatalogRepository,
        currentUserID: UUID
    ) {
        self.posts = posts
        self.recipes = recipes
        self.beans = beans
        self.catalog = catalog
        self.currentUserID = currentUserID
    }
}
