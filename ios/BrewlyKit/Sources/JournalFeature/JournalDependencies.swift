import BrewlyDomain
import Foundation

public struct JournalDependencies: Sendable {
    public var brews: any BrewLogRepository
    public var beans: any BeanRepository
    public var recipes: any RecipeRepository
    public var catalog: any CatalogRepository
    public var equipment: any EquipmentRepository
    public var saveBrew: SaveBrewLogUseCase
    /// The signed-in user, to know which brews can be edited.
    public var currentUserID: UUID

    public init(
        brews: any BrewLogRepository,
        beans: any BeanRepository,
        recipes: any RecipeRepository,
        catalog: any CatalogRepository,
        equipment: any EquipmentRepository,
        saveBrew: SaveBrewLogUseCase,
        currentUserID: UUID
    ) {
        self.brews = brews
        self.beans = beans
        self.recipes = recipes
        self.catalog = catalog
        self.equipment = equipment
        self.saveBrew = saveBrew
        self.currentUserID = currentUserID
    }
}
