import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

/// The signed-in user's gear.
@MainActor
@Observable
final class EquipmentListViewModel {
    private(set) var state: LoadState<[Equipment]> = .idle
    private(set) var catalog: Catalog = .empty
    private(set) var errorMessage: String?

    private let equipment: any EquipmentRepository
    private let catalogRepository: any CatalogRepository

    init(equipment: any EquipmentRepository, catalog: any CatalogRepository) {
        self.equipment = equipment
        self.catalogRepository = catalog
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let items = equipment.myEquipment()
            async let catalog = catalogRepository.catalog()
            let (loadedItems, loadedCatalog) = try await (items, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedItems)
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
        }
    }

    func delete(_ item: Equipment) async {
        do {
            try await equipment.delete(id: item.id)
            state = .loaded((state.value ?? []).filter { $0.id != item.id })
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }
}

/// Creates or edits an item of gear.
@MainActor
@Observable
final class EquipmentFormViewModel {
    var draft: EquipmentDraft
    let catalog: Catalog
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?
    private(set) var isSaving = false

    /// The item being edited, or `nil` when adding one.
    let equipmentID: UUID?
    private let equipment: any EquipmentRepository

    init(item: Equipment?, catalog: Catalog, equipment: any EquipmentRepository) {
        equipmentID = item?.id
        draft = item.map(EquipmentDraft.init(equipment:)) ?? EquipmentDraft()
        self.catalog = catalog
        self.equipment = equipment
    }

    var isEditing: Bool { equipmentID != nil }

    /// The draft names a grinder from the catalog, so brand and model are not needed.
    var usesCatalogGrinder: Bool { draft.kind == .grinder && draft.grinderSlug != nil }

    func message(for field: String) -> String? {
        violations.message(for: field)
    }

    /// Validates and saves the item. Returns it on success.
    func save() async -> Equipment? {
        violations = draft.violations
        guard violations.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await equipment.save(draft, id: equipmentID)
            errorMessage = nil
            return saved
        } catch let DomainError.validation(violations) {
            self.violations = violations
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}
