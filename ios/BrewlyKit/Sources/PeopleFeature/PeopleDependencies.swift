import BrewlyDomain
import Foundation

public struct PeopleDependencies: Sendable {
    public var people: any PeopleRepository
    public var posts: any PostRepository
    public var catalog: any CatalogRepository
    public var equipment: any EquipmentRepository

    public init(
        people: any PeopleRepository,
        posts: any PostRepository,
        catalog: any CatalogRepository,
        equipment: any EquipmentRepository
    ) {
        self.people = people
        self.posts = posts
        self.catalog = catalog
        self.equipment = equipment
    }
}
