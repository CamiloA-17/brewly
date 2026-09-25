import BrewlyDomain

public struct BeansDependencies: Sendable {
    public var beans: any BeanRepository
    public var catalog: any CatalogRepository
    public var saveBean: SaveBeanUseCase

    public init(beans: any BeanRepository, catalog: any CatalogRepository, saveBean: SaveBeanUseCase) {
        self.beans = beans
        self.catalog = catalog
        self.saveBean = saveBean
    }
}
