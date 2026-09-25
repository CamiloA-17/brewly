@testable import BrewlyServer
import BrewlyAPI
import XCTest

final class PageCursorTests: XCTestCase {
    func testRoundTrip() throws {
        let cursor = PageCursor(createdAt: "2026-09-25T13:57:28.526926Z", id: UUID())
        XCTAssertEqual(PageCursor(encoded: cursor.encoded()), cursor)
    }

    func testRejectsGarbage() {
        XCTAssertNil(PageCursor(encoded: "not a cursor"))
    }
}

final class TokenServiceTests: XCTestCase {
    func testRefreshTokensAreRandomAndURLSafe() {
        let first = TokenService.makeRefreshToken()
        let second = TokenService.makeRefreshToken()
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.count, 43)
        XCTAssertNil(first.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
    }

    func testHashIsHexSHA256() {
        XCTAssertEqual(
            TokenService.hash(refreshToken: "abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}

final class RecipeServiceTests: XCTestCase {
    private let service = RecipeService(recipes: UnreachableRecipeRepository(), catalog: StubCatalogRepository())

    func testUnknownMethodIsRejected() async {
        await assertValidationError(fields: ["methodSlug"]) {
            _ = try await self.service.validated(Self.request(methodSlug: "teapot", waterG: 250))
        }
    }

    func testEspressoRequiresBeverageWeight() async {
        await assertValidationError(fields: ["yieldG", "waterG"]) {
            _ = try await self.service.validated(Self.request(methodSlug: "espresso", waterG: 60))
        }
    }

    func testNormalizesOptionalText() async throws {
        var request = Self.request(methodSlug: "v60", waterG: 250)
        request.title = "  Morning V60  "
        request.notes = "   "
        request.flavorNoteSlugs = ["jasmine", "jasmine", "peach"]
        let recipe = try await service.validated(request)
        XCTAssertEqual(recipe.title, "Morning V60")
        XCTAssertNil(recipe.notes)
        XCTAssertEqual(recipe.flavorNoteSlugs, ["jasmine", "peach"])
    }

    private static func request(methodSlug: String, waterG: Double?) -> UpsertRecipeRequest {
        UpsertRecipeRequest(
            beanId: UUID(), methodSlug: methodSlug, title: "Test", doseG: 18, waterG: waterG, grindSize: .fine
        )
    }
}

final class BeanServiceTests: XCTestCase {
    func testRejectsInvertedAltitudeRange() {
        let service = BeanService(beans: UnreachableBeanRepository())
        let request = UpsertBeanRequest(name: "Test", altitudeMinM: 2000, altitudeMaxM: 1500)
        XCTAssertThrowsError(try service.validated(request)) { error in
            XCTAssertEqual((error as? AppError)?.fieldErrors?.map(\.field), ["altitudeMinM"])
        }
    }

    func testNormalizesCountryAndBlankText() throws {
        let service = BeanService(beans: UnreachableBeanRepository())
        let bean = try service.validated(UpsertBeanRequest(name: " Geisha ", countryCode: "co", farm: " "))
        XCTAssertEqual(bean.name, "Geisha")
        XCTAssertEqual(bean.countryCode, "CO")
        XCTAssertNil(bean.farm)
    }
}

// MARK: - Helpers

func assertValidationError(
    fields: Set<String>,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail("Expected a validation error", file: file, line: line)
    } catch let error as AppError {
        XCTAssertEqual(error.status, .unprocessableEntity, file: file, line: line)
        XCTAssertEqual(Set(error.fieldErrors?.map(\.field) ?? []), fields, file: file, line: line)
    } catch {
        XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}

struct StubCatalogRepository: CatalogRepository {
    let methods = [
        BrewMethodDTO(slug: "v60", name: "V60", category: .pourOver, ratioBasis: .water),
        BrewMethodDTO(slug: "espresso", name: "Espresso", category: .espresso, ratioBasis: .beverage),
    ]

    func catalog() async throws -> CatalogDTO {
        CatalogDTO(brewMethods: methods, varietals: [], processingMethods: [], countries: [], grinders: [], flavorNotes: [])
    }

    func brewMethod(slug: String) async throws -> BrewMethodDTO? {
        methods.first { $0.slug == slug }
    }
}

struct UnreachableRecipeRepository: RecipeRepository {
    func list(scope: RecipeListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> Page<RecipeSummaryDTO> {
        fatalError("Not used in unit tests")
    }
    func find(id: UUID, viewerID: UUID) async throws -> RecipeDTO? { fatalError("Not used in unit tests") }
    func create(authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO { fatalError("Not used in unit tests") }
    func update(id: UUID, authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO? {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, authorID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
}

struct UnreachableBeanRepository: BeanRepository {
    func list(ownerID: UUID, includeArchived: Bool) async throws -> [BeanDTO] { fatalError("Not used in unit tests") }
    func find(id: UUID, viewerID: UUID) async throws -> BeanDTO? { fatalError("Not used in unit tests") }
    func create(ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO { fatalError("Not used in unit tests") }
    func update(id: UUID, ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO? {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, ownerID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
}
