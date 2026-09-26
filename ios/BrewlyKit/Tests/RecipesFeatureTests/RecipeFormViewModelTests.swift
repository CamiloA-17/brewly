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
private let sampleBean = Bean(id: UUID(), ownerID: UUID(), name: "Geisha Washed")

struct StubCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog {
        Catalog(brewMethods: [v60, espresso])
    }
}

struct StubBeanRepository: BeanRepository {
    func myBeans(includeArchived: Bool) async throws -> [Bean] { [sampleBean] }
    func bean(id: UUID) async throws -> Bean { sampleBean }
    func create(_ draft: BeanDraft) async throws -> Bean { sampleBean }
    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean { sampleBean }
    func delete(id: UUID) async throws {}
}

struct StubUserMethodsRepository: UserMethodsRepository {
    func myMethodSlugs() async throws -> Set<String> { ["espresso"] }
    func setUsing(_ isUsing: Bool, methodSlug: String) async throws {}
}

struct StubEquipmentRepository: EquipmentRepository {
    var items: [Equipment] = []

    func myEquipment() async throws -> [Equipment] { items }
    func equipment(ofMember memberID: UUID) async throws -> [Equipment] { items }
    func save(_ draft: EquipmentDraft, id: UUID?) async throws -> Equipment { throw DomainError.notFound }
    func delete(id: UUID) async throws {}
}

/// Saves succeed unless `failing` is set; the count starts at `initialCount`.
actor StubSavesRepository: RecipeSavesRepository {
    var failing = false
    private var count: Int

    init(initialCount: Int = 0, failing: Bool = false) {
        count = initialCount
        self.failing = failing
    }

    func savedRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> { PagedResult(items: [], nextCursor: nil) }
    func save(recipeID: UUID) async throws -> SaveState {
        if failing { throw DomainError.offline }
        count += 1
        return SaveState(isSaved: true, saveCount: count)
    }
    func unsave(recipeID: UUID) async throws -> SaveState {
        if failing { throw DomainError.offline }
        count -= 1
        return SaveState(isSaved: false, saveCount: count)
    }
}

actor RecordingRecipeRepository: RecipeRepository {
    private(set) var created: [RecipeInput] = []

    func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> { PagedResult(items: [], nextCursor: nil) }
    func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        PagedResult(items: [], nextCursor: nil)
    }
    var stored: Recipe?

    func store(_ recipe: Recipe) { stored = recipe }
    func recipe(id: UUID) async throws -> Recipe {
        guard let stored else { throw DomainError.notFound }
        return stored
    }

    func create(_ input: RecipeInput) async throws -> Recipe {
        created.append(input)
        return Recipe(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "ana.barista", displayName: "Ana"),
            bean: BeanSummary(id: input.beanID, name: sampleBean.name),
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
    private func makeModel(
        recipes: RecordingRecipeRepository,
        equipment: [Equipment] = []
    ) -> RecipeFormViewModel {
        let dependencies = RecipesDependencies(
            recipes: recipes,
            saves: StubSavesRepository(),
            beans: StubBeanRepository(),
            catalog: StubCatalogRepository(),
            userMethods: StubUserMethodsRepository(),
            equipment: StubEquipmentRepository(items: equipment),
            saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: UUID()
        )
        return RecipeFormViewModel(recipe: nil, dependencies: dependencies)
    }

    @Test("A remix sends the original's id and waits for one of the user's beans")
    func remix() async {
        let recipes = RecordingRecipeRepository()
        let original = Recipe(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "leo.roaster", displayName: "Leo"),
            bean: BeanSummary(id: UUID(), name: "Leo's bean"),
            methodSlug: "v60", title: "Floral V60", doseG: 15, waterG: 250, ratio: 16.7,
            grindSize: .mediumFine, notes: "Leo's notes"
        )
        let dependencies = RecipesDependencies(
            recipes: recipes, saves: StubSavesRepository(), beans: StubBeanRepository(),
            catalog: StubCatalogRepository(), userMethods: StubUserMethodsRepository(),
            equipment: StubEquipmentRepository(), saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: UUID()
        )
        let model = RecipeFormViewModel(recipe: nil, remixOf: original, dependencies: dependencies)
        #expect(model.isRemix)
        #expect(model.draft.beanID == nil)
        #expect(model.draft.notes.isEmpty)

        await model.load()
        #expect(model.draft.beanID == sampleBean.id)
        _ = await model.save()
        let input = await recipes.created.first
        #expect(input?.draft.forkedFromID == original.id)
        #expect(input?.beanID == sampleBean.id)
    }

    @Test("A new recipe starts with the default grinder and its setting for the method")
    func prefillsUsualGrind() async {
        let grinder = Equipment(
            id: UUID(), kind: .grinder, grinderSlug: "comandante_c40_mk4", isDefault: true,
            grindSettings: ["v60": "24 clicks"]
        )
        let model = makeModel(recipes: RecordingRecipeRepository(), equipment: [grinder])
        await model.load()
        #expect(model.draft.grinderSlug == "comandante_c40_mk4")
        model.selectMethod("v60")
        #expect(model.draft.grindSetting == "24 clicks")
    }

    @Test("Loading selects the first bean and lists the user's methods first")
    func load() async {
        let model = makeModel(recipes: RecordingRecipeRepository())
        await model.load()
        #expect(model.draft.beanID == sampleBean.id)
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

@MainActor
@Suite("RecipeDetailViewModel")
struct RecipeDetailViewModelTests {
    private func makeModel(saves: StubSavesRepository) async -> RecipeDetailViewModel {
        let recipes = RecordingRecipeRepository()
        let recipe = Recipe(
            id: UUID(),
            author: UserSummary(id: UUID(), username: "leo.roaster", displayName: "Leo"),
            bean: BeanSummary(id: UUID(), name: "Leo's bean"),
            methodSlug: "v60", title: "Floral V60", doseG: 15, ratio: 16,
            grindSize: .mediumFine, saveCount: 2
        )
        await recipes.store(recipe)
        let dependencies = RecipesDependencies(
            recipes: recipes, saves: saves, beans: StubBeanRepository(),
            catalog: StubCatalogRepository(), userMethods: StubUserMethodsRepository(),
            equipment: StubEquipmentRepository(), saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: UUID()
        )
        let model = RecipeDetailViewModel(recipeID: recipe.id, dependencies: dependencies)
        await model.load()
        return model
    }

    @Test("Saving updates the recipe with the server's count")
    func save() async {
        let model = await makeModel(saves: StubSavesRepository(initialCount: 2))
        #expect(model.isOwner == false)
        await model.toggleSave()
        #expect(model.state.value?.isSaved == true)
        #expect(model.state.value?.saveCount == 3)
    }

    @Test("A failed save reverts the change and shows an error")
    func failedSave() async {
        let model = await makeModel(saves: StubSavesRepository(initialCount: 2, failing: true))
        await model.toggleSave()
        #expect(model.state.value?.isSaved == false)
        #expect(model.state.value?.saveCount == 2)
        #expect(model.errorMessage != nil)
    }
}
