import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class RecipeDetailViewModel {
    private(set) var state: LoadState<Recipe> = .idle
    private(set) var catalog: Catalog = .empty
    private(set) var errorMessage: String?

    let recipeID: UUID
    let dependencies: RecipesDependencies

    init(recipeID: UUID, dependencies: RecipesDependencies) {
        self.recipeID = recipeID
        self.dependencies = dependencies
    }

    var isOwner: Bool {
        state.value?.author.id == dependencies.currentUserID
    }

    var method: BrewMethod? {
        catalog.brewMethod(state.value?.methodSlug)
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let recipe = dependencies.recipes.recipe(id: recipeID)
            async let catalog = dependencies.catalog.catalog()
            let (loadedRecipe, loadedCatalog) = try await (recipe, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedRecipe)
        } catch {
            state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
        }
    }

    func replace(with recipe: Recipe) {
        state = .loaded(recipe)
    }

    /// Saves or unsaves the recipe, updating the screen right away and reverting on failure.
    func toggleSave() async {
        guard var recipe = state.value else { return }
        let original = recipe
        let saving = !recipe.isSaved
        recipe.isSaved = saving
        recipe.saveCount = max(0, recipe.saveCount + (saving ? 1 : -1))
        state = .loaded(recipe)
        do {
            let saved = saving
                ? try await dependencies.saves.save(recipeID: recipeID)
                : try await dependencies.saves.unsave(recipeID: recipeID)
            recipe.isSaved = saved.isSaved
            recipe.saveCount = saved.saveCount
            state = .loaded(recipe)
            errorMessage = nil
        } catch {
            state = .loaded(original)
            errorMessage = error.brewlyMessage
        }
    }

    /// Returns `true` when the recipe was deleted.
    func delete() async -> Bool {
        do {
            try await dependencies.recipes.delete(id: recipeID)
            return true
        } catch {
            errorMessage = error.brewlyMessage
            return false
        }
    }
}
