import BrewlyDomain
import Foundation
@testable import JournalFeature
import Testing

private let v60 = BrewMethod(
    slug: "v60", name: "V60", category: .pourOver, ratioBasis: .water,
    defaultRatio: 16, defaultGrindSize: .mediumFine, defaultWaterTempC: 93
)
private let espresso = BrewMethod(
    slug: "espresso", name: "Espresso", category: .espresso, ratioBasis: .beverage,
    defaultRatio: 2, defaultGrindSize: .fine, defaultWaterTempC: 93
)
private let myBean = Bean(id: UUID(), ownerID: UUID(), name: "Geisha Washed", remainingG: 220)
private let leo = UserSummary(id: UUID(), username: "leo.roaster", displayName: "Leo")
private let floralV60 = Recipe(
    id: UUID(), author: leo, bean: BeanSummary(id: UUID(), name: "Leo's bean"), methodSlug: "v60",
    title: "Floral V60", doseG: 15, waterG: 250, ratio: 16.7, grindSize: .mediumFine, grindSetting: "22 clicks",
    waterTempC: 93, totalTimeS: 180
)

struct StubCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog { Catalog(brewMethods: [v60, espresso]) }
}

struct StubBeanRepository: BeanRepository {
    func myBeans(includeArchived: Bool) async throws -> [Bean] { [myBean] }
    func bean(id: UUID) async throws -> Bean { myBean }
    func create(_ draft: BeanDraft) async throws -> Bean { myBean }
    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean { myBean }
    func delete(id: UUID) async throws {}
}

struct StubRecipeRepository: RecipeRepository {
    func myRecipes(cursor: String?) async throws -> PagedResult<RecipeSummary> { PagedResult(items: [], nextCursor: nil) }
    func explore(filter: RecipeFilter, cursor: String?) async throws -> PagedResult<RecipeSummary> {
        PagedResult(items: [], nextCursor: nil)
    }
    func recipe(id: UUID) async throws -> Recipe { floralV60 }
    func create(_ input: RecipeInput) async throws -> Recipe { floralV60 }
    func update(id: UUID, _ input: RecipeInput) async throws -> Recipe { floralV60 }
    func delete(id: UUID) async throws {}
}

struct StubEquipmentRepository: EquipmentRepository {
    var items: [Equipment] = []

    func myEquipment() async throws -> [Equipment] { items }
    func equipment(ofMember memberID: UUID) async throws -> [Equipment] { items }
    func save(_ draft: EquipmentDraft, id: UUID?) async throws -> Equipment { throw DomainError.notFound }
    func delete(id: UUID) async throws {}
}

/// Records what the form saves.
actor RecordingBrewLogRepository: BrewLogRepository {
    private(set) var saved: [(draft: BrewLogDraft, beanID: UUID, methodSlug: String)] = []

    func myBrews(filter: BrewLogFilter, cursor: String?) async throws -> PagedResult<BrewLog> {
        PagedResult(items: [], nextCursor: nil)
    }

    func brew(id: UUID) async throws -> BrewLog { throw DomainError.notFound }

    func save(_ draft: BrewLogDraft, beanID: UUID, methodSlug: String, id: UUID?) async throws -> BrewLog {
        saved.append((draft, beanID, methodSlug))
        return BrewLog(
            id: id ?? UUID(), user: leo, bean: BeanSummary(id: beanID, name: myBean.name), methodSlug: methodSlug,
            brewedAt: draft.brewedAt, doseG: draft.doseG ?? 0
        )
    }

    func delete(id: UUID) async throws {}
}

@MainActor
@Suite("BrewLogFormViewModel")
struct BrewLogFormViewModelTests {
    private func makeModel(
        recipeID: UUID? = nil,
        equipment: [Equipment] = [],
        brews: RecordingBrewLogRepository = RecordingBrewLogRepository()
    ) -> BrewLogFormViewModel {
        let dependencies = JournalDependencies(
            brews: brews, beans: StubBeanRepository(), recipes: StubRecipeRepository(),
            catalog: StubCatalogRepository(), equipment: StubEquipmentRepository(items: equipment),
            saveBrew: SaveBrewLogUseCase(brews: brews), currentUserID: UUID()
        )
        return BrewLogFormViewModel(brewLog: nil, recipeID: recipeID, dependencies: dependencies)
    }

    @Test("Brewing someone else's recipe copies its parameters and uses one of my beans")
    func fromRecipe() async {
        let model = makeModel(recipeID: floralV60.id)
        await model.load()
        #expect(model.draft.recipeID == floralV60.id)
        #expect(model.draft.recipeTitle == "Floral V60")
        #expect(model.draft.methodSlug == "v60")
        #expect(model.draft.doseG == 15)
        #expect(model.draft.grindSetting == "22 clicks")
        #expect(model.draft.beanID == myBean.id)
        #expect(model.draft.visibility == .private)
    }

    @Test("A new brew uses the default grinder and its setting for the method")
    func usualGrind() async {
        let grinder = Equipment(
            id: UUID(), kind: .grinder, grinderSlug: "comandante_c40_mk4", isDefault: true,
            grindSettings: ["espresso": "8 clicks"]
        )
        let model = makeModel(equipment: [grinder])
        await model.load()
        #expect(model.draft.equipmentID == grinder.id)
        model.selectMethod("espresso")
        #expect(model.draft.grindSetting == "8 clicks")
    }

    @Test("Espresso brews drop the brew water and need the beverage weight")
    func espressoValidation() async {
        let brews = RecordingBrewLogRepository()
        let model = makeModel(brews: brews)
        await model.load()
        model.draft.waterG = 250
        model.selectMethod("espresso")
        model.draft.doseG = 18
        #expect(model.draft.waterG == nil)
        #expect(await model.save() == nil)
        #expect(model.message(for: "yieldG") != nil)

        model.draft.yieldG = 36
        model.draft.tasting.rating = 4
        let saved = await model.save()
        #expect(saved?.methodSlug == "espresso")
        #expect(await brews.saved.first?.draft.tasting.rating == 4)
    }
}
