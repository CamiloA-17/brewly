import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class RecipeFormViewModel {
    var draft: RecipeDraft
    private(set) var catalog: Catalog = .empty
    private(set) var beans: [Bean] = []
    private(set) var myMethodSlugs: Set<String> = []
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?
    private(set) var isSaving = false
    private(set) var isLoading = true

    /// The recipe being edited, or `nil` when creating one.
    let recipeID: UUID?
    private let dependencies: RecipesDependencies

    /// - Parameters:
    ///   - recipe: The recipe to edit, or `nil` to create one.
    ///   - remixOf: A recipe to start from when creating a remix.
    init(recipe: Recipe?, remixOf original: Recipe? = nil, dependencies: RecipesDependencies) {
        self.recipeID = recipe?.id
        if let recipe {
            draft = RecipeDraft(recipe: recipe)
        } else if let original {
            draft = RecipeDraft(remixOf: original)
        } else {
            draft = RecipeDraft()
        }
        self.dependencies = dependencies
    }

    var isEditing: Bool { recipeID != nil }

    var isRemix: Bool { !isEditing && draft.forkedFromID != nil }

    var method: BrewMethod? { catalog.brewMethod(draft.methodSlug) }

    var ratioBasis: RatioBasis { method?.ratioBasis ?? .water }

    /// The user's methods first, then the rest of the catalog.
    var methodsSortedForPicker: [BrewMethod] {
        catalog.brewMethods.filter { myMethodSlugs.contains($0.slug) }
            + catalog.brewMethods.filter { !myMethodSlugs.contains($0.slug) }
    }

    func load() async {
        defer { isLoading = false }
        do {
            async let catalog = dependencies.catalog.catalog()
            async let beans = dependencies.beans.myBeans(includeArchived: isEditing)
            async let methods = dependencies.userMethods.myMethodSlugs()
            let (loadedCatalog, loadedBeans, loadedMethods) = try await (catalog, beans, methods)
            self.catalog = loadedCatalog
            self.beans = loadedBeans
            self.myMethodSlugs = loadedMethods
            if draft.beanID == nil { draft.beanID = loadedBeans.first?.id }
        } catch {
            errorMessage = error.brewlyMessage
        }
    }

    /// Selects a brew method and prefills its suggested parameters.
    func selectMethod(_ slug: String?) {
        guard let method = catalog.brewMethod(slug) else {
            draft.methodSlug = nil
            return
        }
        draft.applyDefaults(of: method)
    }

    func message(for field: String) -> String? {
        violations.message(for: field)
    }

    func addStep() {
        let lastStart = draft.steps.last?.startS ?? -30
        let kind: BrewStepKind = draft.steps.isEmpty ? .bloom : .pour
        draft.steps.append(RecipeDraft.Step(kind: kind, startS: lastStart + 30))
    }

    func removeSteps(at offsets: IndexSet) {
        draft.steps.remove(atOffsets: offsets)
    }

    func moveSteps(from source: IndexSet, to destination: Int) {
        draft.steps.move(fromOffsets: source, toOffset: destination)
    }

    /// Validates and saves the recipe. Returns it on success.
    func save() async -> Recipe? {
        violations = SaveRecipeUseCase.violations(for: draft, method: method)
        guard violations.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }
        do {
            let recipe = try await dependencies.saveRecipe(draft, method: method, id: recipeID)
            errorMessage = nil
            return recipe
        } catch let DomainError.validation(violations) {
            self.violations = violations
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}
