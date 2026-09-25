import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class BeanFormViewModel {
    var draft: BeanDraft
    private(set) var catalog: Catalog = .empty
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?
    private(set) var isSaving = false

    /// The bean being edited, or `nil` when creating one.
    let beanID: UUID?
    private let dependencies: BeansDependencies

    init(bean: Bean?, dependencies: BeansDependencies) {
        self.beanID = bean?.id
        self.draft = bean.map(BeanDraft.init(bean:)) ?? BeanDraft()
        self.dependencies = dependencies
    }

    var isEditing: Bool { beanID != nil }

    func loadCatalog() async {
        catalog = (try? await dependencies.catalog.catalog()) ?? .empty
    }

    func message(for field: String) -> String? {
        violations.message(for: field)
    }

    /// Validates and saves the bean. Returns it on success.
    func save() async -> Bean? {
        violations = SaveBeanUseCase.violations(for: draft)
        guard violations.isEmpty else { return nil }

        isSaving = true
        defer { isSaving = false }
        do {
            let bean = try await dependencies.saveBean(draft, id: beanID)
            errorMessage = nil
            return bean
        } catch let DomainError.validation(violations) {
            self.violations = violations
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }
}
