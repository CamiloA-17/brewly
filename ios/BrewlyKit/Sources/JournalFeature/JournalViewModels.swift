import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

/// The member's journal, most recent brew first, optionally for one bean.
@MainActor
@Observable
final class JournalViewModel {
    private(set) var brews: Paginator<BrewLog>
    private(set) var catalog: Catalog = .empty
    private(set) var beans: [Bean] = []
    private(set) var filter = BrewLogFilter()

    private let dependencies: JournalDependencies

    init(dependencies: JournalDependencies) {
        self.dependencies = dependencies
        brews = Self.paginator(filter: BrewLogFilter(), brews: dependencies.brews)
    }

    func load() async {
        async let catalog = try? dependencies.catalog.catalog()
        async let beans = try? dependencies.beans.myBeans(includeArchived: true)
        let (loadedCatalog, loadedBeans) = await (catalog, beans)
        if let loadedCatalog { self.catalog = loadedCatalog }
        if let loadedBeans { self.beans = loadedBeans }
        await brews.load()
    }

    /// Shows only the brews of one bean, or all of them with `nil`.
    func filter(beanID: UUID?) async {
        filter.beanID = beanID
        brews = Self.paginator(filter: filter, brews: dependencies.brews)
        await brews.load()
    }

    var filteredBeanName: String? {
        filter.beanID.flatMap { id in beans.first { $0.id == id }?.name }
    }

    /// The loaded brews grouped by calendar day, most recent first.
    var days: [(day: Date, brews: [BrewLog])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: brews.state.value ?? []) { calendar.startOfDay(for: $0.brewedAt) }
        return groups.keys.sorted(by: >).map { (day: $0, brews: groups[$0] ?? []) }
    }

    private static func paginator(filter: BrewLogFilter, brews: any BrewLogRepository) -> Paginator<BrewLog> {
        Paginator { cursor in try await brews.myBrews(filter: filter, cursor: cursor) }
    }
}

/// A journal entry, editable by its owner.
@MainActor
@Observable
final class BrewLogDetailViewModel {
    private(set) var state: LoadState<BrewLog> = .idle
    private(set) var catalog: Catalog = .empty
    private(set) var equipment: [Equipment] = []
    private(set) var errorMessage: String?

    let brewID: UUID
    let dependencies: JournalDependencies

    init(brewID: UUID, dependencies: JournalDependencies) {
        self.brewID = brewID
        self.dependencies = dependencies
    }

    var isMine: Bool { state.value?.user.id == dependencies.currentUserID }

    /// The name of the gear used, if it still exists.
    var equipmentName: String? {
        guard let id = state.value?.equipmentID else { return nil }
        return equipment.first { $0.id == id }?.displayName(in: catalog)
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let brew = dependencies.brews.brew(id: brewID)
            async let catalog = dependencies.catalog.catalog()
            let (loadedBrew, loadedCatalog) = try await (brew, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedBrew)
            if loadedBrew.user.id == dependencies.currentUserID {
                equipment = (try? await dependencies.equipment.myEquipment()) ?? []
            }
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
        }
    }

    func didSave(_ brew: BrewLog) {
        state = .loaded(brew)
    }

    /// Returns `true` when the brew was deleted.
    func delete() async -> Bool {
        do {
            try await dependencies.brews.delete(id: brewID)
            return true
        } catch {
            errorMessage = error.brewlyMessage
            return false
        }
    }
}

/// Creates or edits a journal entry, optionally starting from a recipe.
@MainActor
@Observable
final class BrewLogFormViewModel {
    var draft: BrewLogDraft
    private(set) var catalog: Catalog = .empty
    private(set) var beans: [Bean] = []
    private(set) var equipment: [Equipment] = []
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?
    private(set) var isSaving = false
    private(set) var isLoading = true

    /// The brew being edited, or `nil` when logging a new one.
    let brewID: UUID?
    private let recipeID: UUID?
    private let dependencies: JournalDependencies

    init(brewLog: BrewLog?, recipeID: UUID? = nil, dependencies: JournalDependencies) {
        brewID = brewLog?.id
        self.recipeID = recipeID
        draft = brewLog.map(BrewLogDraft.init(brewLog:)) ?? BrewLogDraft()
        self.dependencies = dependencies
    }

    var isEditing: Bool { brewID != nil }

    var method: BrewMethod? { catalog.brewMethod(draft.methodSlug) }

    var ratioBasis: RatioBasis { method?.ratioBasis ?? .water }

    var grinders: [Equipment] { equipment.filter { $0.kind == .grinder } }

    func load() async {
        defer { isLoading = false }
        do {
            async let catalog = dependencies.catalog.catalog()
            async let beans = dependencies.beans.myBeans(includeArchived: isEditing)
            let (loadedCatalog, loadedBeans) = try await (catalog, beans)
            self.catalog = loadedCatalog
            self.beans = loadedBeans
        } catch {
            errorMessage = error.brewlyMessage
        }
        equipment = (try? await dependencies.equipment.myEquipment()) ?? []
        guard !isEditing else { return }

        if let recipeID, let recipe = try? await dependencies.recipes.recipe(id: recipeID) {
            draft = BrewLogDraft(recipe: recipe)
            // Brewing one's own recipe uses its bean when it is still in the pantry.
            if beans.contains(where: { $0.id == recipe.bean.id }) { draft.beanID = recipe.bean.id }
        }
        if draft.beanID == nil { draft.beanID = beans.first?.id }
        draft.applyUsualGrind(from: equipment)
    }

    /// Selects a brew method; espresso-style methods don't use brew water.
    func selectMethod(_ slug: String?) {
        draft.methodSlug = slug
        if method?.ratioBasis == .beverage { draft.waterG = nil }
        if !isEditing { draft.applyUsualGrind(from: equipment) }
    }

    /// Picks another grinder and, for a new brew, its usual setting for the method.
    func selectGrinder(_ id: UUID?) {
        draft.equipmentID = id
        guard !isEditing, let grinder = grinders.first(where: { $0.id == id }),
              let slug = draft.methodSlug, let setting = grinder.grindSettings[slug]
        else { return }
        draft.grindSetting = setting
    }

    func message(for field: String) -> String? {
        violations.message(for: field)
    }

    /// Validates and saves the brew. Returns it on success.
    func save() async -> BrewLog? {
        violations = SaveBrewLogUseCase.violations(for: draft, method: method)
        guard violations.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }
        do {
            let brew = try await dependencies.saveBrew(draft, method: method, id: brewID)
            errorMessage = nil
            return brew
        } catch let DomainError.validation(violations) {
            self.violations = violations
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}
