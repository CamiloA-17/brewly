import BrewlyDomain
import Foundation

public struct RecipesDependencies: Sendable {
    public var recipes: any RecipeRepository
    public var beans: any BeanRepository
    public var catalog: any CatalogRepository
    public var userMethods: any UserMethodsRepository
    public var saveRecipe: SaveRecipeUseCase
    /// The signed-in user, to know which recipes can be edited.
    public var currentUserID: UUID

    public init(
        recipes: any RecipeRepository,
        beans: any BeanRepository,
        catalog: any CatalogRepository,
        userMethods: any UserMethodsRepository,
        saveRecipe: SaveRecipeUseCase,
        currentUserID: UUID
    ) {
        self.recipes = recipes
        self.beans = beans
        self.catalog = catalog
        self.userMethods = userMethods
        self.saveRecipe = saveRecipe
        self.currentUserID = currentUserID
    }
}
