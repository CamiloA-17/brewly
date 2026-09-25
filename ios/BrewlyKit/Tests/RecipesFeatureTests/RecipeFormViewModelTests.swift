import BrewlyDomain
import Foundation
@testable import RecipesFeature
import Testing

private let v60 = BrewMethod(
    slug: "v60", name: "V60", category: .pourOver, ratioBasis: .water,
    defaultRatio: 16, defaultGrindSize: .mediumFine, defaultWaterTempC: 93
)
private let espresso = BrewMethod(
    slug: "espresso", name: "Espresso", category: .espresso, ratioBasis: .beverage,
    defaultRatio: 2, defaultGrindSize: .fine, defaultWaterTempC: 93
)
private let bean = Bean(id: UUID(), ownerID: UUID(), name: "Geisha Washed")

struct StubCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog {
        Catalog(brewMethods: [v60, espresso])
    }
}

struct StubBeanRepository: BeanRepository {
    func myBeans(includeArchived: Bool) async throws -> [Bean] { [bean] }
    func bean(id: UUID) async throws -> Bean { bean }
    func create(_ draft: BeanDraft) async throws -> Bean { bean }
    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean { bean }
    func delete(id: UUID) async throws {}
}

struct StubUserMethodsRepository: UserMethodsRepository {
    func myMethodSlugs() async throws -> Set<String> { ["espresso"] }
    func setUsing(_ isUsing: Bool, methodSlug: String) async throws {}
}

actor RecordingRecipeRepository: RecipeRepository {
    private(set) var created: [RecipeInput] = []

    func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> { PagedResult(items: [], nextCursor: nil) }
    func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        PagedResult(items: [], nextCursor: nil)
    }
    func recipe(id: UUID) async throws -> Recipe { throw DomainError.notFound }

    func create(_ input: RecipeInput) async throws -> Recipe {
        created.append(input)
        return Recipe(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "ana.barista", displayName: "Ana"),
            bean: BeanSummary(id: input.beanID, name: bean.name),
            methodSlug: input.methodSlug,
            title: input.draft.title,
            doseG: input.draft.doseG ?? 0,
            ratio: input.draft.ratio ?? 0,
            grindSize: input.draft.grindSize
        )
    }

    func update(id: UUID, _ input: RecipeInput) async throws -> Recipe { try await create(input) }
    func delete(id: UUID) async throws {}
}

@MainActor
@Suite("RecipeFormViewModel")
struct RecipeFormViewModelTests {
    private func makeModel(recipes: RecordingRecipeRepository) -> RecipeFormViewModel {
        let dependencies = RecipesDependencies(
            recipes: recipes,
            beans: StubBeanRepository(),
            catalog: StubCatalogRepository(),
            userMethods: StubUserMethodsRepository(),
            saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: UUID()
        )
        return RecipeFormViewModel(recipe: nil, dependencies: dependencies)
    }

    @Test("Loading selects the first bean and lists the user's methods first")
    func load() async {
        let model = makeModel(recipes: RecordingRecipeRepository())
        await model.load()
        #expect(model.draft.beanID == bean.id)
        #expect(model.methodsSortedForPicker.map(\.slug) == ["espresso", "v60"])
    }

    @Test("Selecting a method prefills its suggestions and the live ratio")
    func selectMethod() async {
        let model = makeModel(recipes: RecordingRecipeRepository())
        await model.load()
        model.draft.doseG = 15
        model.selectMethod("v60")
        #expect(model.draft.waterG == 240)
        #expect(model.draft.ratio == 16)
        #expect(model.ratioBasis == .water)
    }

    @Test("Saving sends a validated recipe")
    func save() async {
        let recipes = RecordingRecipeRepository()
        let model = makeModel(recipes: recipes)
        await model.load()
        model.draft.title = "Classic shot"
        model.draft.doseG = 18
        model.selectMethod("espresso")

        let saved = await model.save()

        #expect(saved?.title == "Classic shot")
        #expect(model.violations.isEmpty)
        let input = await recipes.created.first
        #expect(input?.methodSlug == "espresso")
        #expect(input?.draft.yieldG == 36)
        #expect(input?.draft.waterG == nil)
    }

    @Test("Missing fields are reported without saving")
    func invalid() async {
        let recipes = RecordingRecipeRepository()
        let model = makeModel(recipes: recipes)
        await model.load()

        let saved = await model.save()

        #expect(saved == nil)
        #expect(Set(model.violations.map(\.field)) == ["methodSlug", "doseG"])
        #expect(await recipes.created.isEmpty)
    }
}
