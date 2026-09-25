import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class BeanListViewModel {
    private(set) var state: LoadState<[Bean]> = .idle
    private(set) var catalog: Catalog = .empty
    var includeArchived = false

    let dependencies: BeansDependencies

    init(dependencies: BeansDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let beans = dependencies.beans.myBeans(includeArchived: includeArchived)
            async let catalog = dependencies.catalog.catalog()
            let (loadedBeans, loadedCatalog) = try await (beans, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedBeans)
        } catch {
            state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
        }
    }
}
