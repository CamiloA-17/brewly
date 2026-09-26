import BrewlyDomain
import Foundation

public struct RecipesDependencies: Sendable {
    public var recipes: any RecipeRepository
    public var saves: any RecipeSavesRepository
    public var beans: any BeanRepository
    public var catalog: any CatalogRepository
    public var userMethods: any UserMethodsRepository
    /// The user's gear: the default grinder pre-fills new recipes.
    public var equipment: any EquipmentRepository
    public var saveRecipe: SaveRecipeUseCase
    /// The signed-in user, to know which recipes can be edited.
    public var currentUserID: UUID

    public init(
        recipes: any RecipeRepository,
        saves: any RecipeSavesRepository,
        beans: any BeanRepository,
        catalog: any CatalogRepository,
        userMethods: any UserMethodsRepository,
        equipment: any EquipmentRepository,
        saveRecipe: SaveRecipeUseCase,
        currentUserID: UUID
    ) {
        self.recipes = recipes
        self.saves = saves
        self.beans = beans
        self.catalog = catalog
        self.userMethods = userMethods
        self.equipment = equipment
        self.saveRecipe = saveRecipe
        self.currentUserID = currentUserID
    }
}
