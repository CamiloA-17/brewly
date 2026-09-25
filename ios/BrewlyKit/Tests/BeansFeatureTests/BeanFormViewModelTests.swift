@testable import BeansFeature
import BrewlyDomain
import Foundation
import Testing

actor FakeBeanRepository: BeanRepository {
    private(set) var created: [BeanDraft] = []

    func myBeans(includeArchived: Bool) async throws -> [Bean] { [] }
    func bean(id: UUID) async throws -> Bean { throw DomainError.notFound }

    func create(_ draft: BeanDraft) async throws -> Bean {
        created.append(draft)
        return Bean(id: UUID(), ownerID: UUID(), name: draft.name)
    }

    func update(id: UUID, _ draft: BeanDraft) async throws -> Bean {
        Bean(id: id, ownerID: UUID(), name: draft.name)
    }

    func delete(id: UUID) async throws {}
}

struct EmptyCatalogRepository: CatalogRepository {
    func catalog(forceRefresh: Bool) async throws -> Catalog { .empty }
}

@MainActor
@Suite("BeanFormViewModel")
struct BeanFormViewModelTests {
    private func makeModel(repository: FakeBeanRepository) -> BeanFormViewModel {
        let dependencies = BeansDependencies(
            beans: repository, catalog: EmptyCatalogRepository(), saveBean: SaveBeanUseCase(beans: repository)
        )
        return BeanFormViewModel(bean: nil, dependencies: dependencies)
    }

    @Test("Invalid drafts are not sent")
    func invalidDraft() async {
        let repository = FakeBeanRepository()
        let model = makeModel(repository: repository)
        model.draft.altitudeMinM = 2000
        model.draft.altitudeMaxM = 1500

        let saved = await model.save()

        #expect(saved == nil)
        #expect(Set(model.violations.map(\.field)) == ["name", "altitudeMinM"])
        #expect(await repository.created.isEmpty)
    }

    @Test("Valid drafts are saved")
    func validDraft() async {
        let repository = FakeBeanRepository()
        let model = makeModel(repository: repository)
        model.draft.name = "Geisha Washed"
        model.draft.farm = "Finca Las Nubes"

        let saved = await model.save()

        #expect(saved?.name == "Geisha Washed")
        #expect(model.violations.isEmpty)
        #expect(await repository.created.first?.farm == "Finca Las Nubes")
    }
}
