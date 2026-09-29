import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class RecipeListViewModel {
    private(set) var state: LoadState<[RecipeSummary]> = .idle
    private(set) var catalog: Catalog = .empty
    private(set) var isLoadingMore = false
    private var nextCursor: String?

    let dependencies: RecipesDependencies

    init(dependencies: RecipesDependencies) {
        self.dependencies = dependencies
    }

    var canLoadMore: Bool { nextCursor != nil }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            if catalog.brewMethods.isEmpty {
                catalog = try await dependencies.catalog.catalog()
            }
            let page = try await fetch(cursor: nil)
            nextCursor = page.nextCursor
            state = .loaded(page.items)
        } catch {
            state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, let current = state.value else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await fetch(cursor: cursor)
            nextCursor = page.nextCursor
            state = .loaded(current + page.items)
        } catch {
            // Keep the loaded items; the user can pull to refresh.
            nextCursor = nil
        }
    }

    private func fetch(cursor: String?) async throws -> PagedResult<RecipeSummary> {
        try await dependencies.recipes.myRecipes(cursor: cursor)
    }
}
