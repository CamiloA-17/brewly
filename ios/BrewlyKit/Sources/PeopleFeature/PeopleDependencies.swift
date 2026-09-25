import BrewlyDomain
import Foundation

public struct PeopleDependencies: Sendable {
    public var people: any PeopleRepository
    public var posts: any PostRepository
    public var catalog: any CatalogRepository

    public init(people: any PeopleRepository, posts: any PostRepository, catalog: any CatalogRepository) {
        self.people = people
        self.posts = posts
        self.catalog = catalog
    }
}
