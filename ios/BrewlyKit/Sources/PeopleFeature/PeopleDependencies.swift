import BrewlyDomain
import Foundation

public struct PeopleDependencies: Sendable {
    public var people: any PeopleRepository
    public var catalog: any CatalogRepository

    public init(people: any PeopleRepository, catalog: any CatalogRepository) {
        self.people = people
        self.catalog = catalog
    }
}
