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

final class EquipmentServiceTests: XCTestCase {
    func testKeepsOneSettingPerMethodAndBlankTextBecomesNil() throws {
        let service = EquipmentService(equipment: UnreachableEquipmentRepository())
        let item = try service.validated(UpsertEquipmentRequest(
            kind: .grinder, grinderSlug: "comandante_c40_mk4", brand: " ", nickname: " My C40 ",
            grindSettings: [
                GrindSettingInput(methodSlug: "v60", grindSetting: "22 clicks"),
                GrindSettingInput(methodSlug: "aeropress", grindSetting: " 18 clicks "),
                GrindSettingInput(methodSlug: "v60", grindSetting: "24 clicks"),
            ]
        ))
        XCTAssertNil(item.brand)
        XCTAssertEqual(item.nickname, "My C40")
        XCTAssertEqual(item.grindSettings, [
            GrindSettingInput(methodSlug: "aeropress", grindSetting: "18 clicks"),
            GrindSettingInput(methodSlug: "v60", grindSetting: "24 clicks"),
        ])
    }

    func testOnlyGrindersHaveSettings() {
        let service = EquipmentService(equipment: UnreachableEquipmentRepository())
        let request = UpsertEquipmentRequest(
            kind: .kettle, brand: "Fellow", grindSettings: [GrindSettingInput(methodSlug: "v60", grindSetting: "24")]
        )
        XCTAssertThrowsError(try service.validated(request)) { error in
            XCTAssertEqual((error as? AppError)?.fieldErrors?.map(\.field), ["grindSettings"])
        }
    }
}

final class BrewLogServiceTests: XCTestCase {
    private let service = BrewLogService(
        brews: UnreachableBrewLogRepository(), recipes: UnreachableRecipeRepository(), catalog: StubCatalogRepository()
    )

    func testEspressoBrewNeedsYieldAndRejectsFutureDates() async {
        let now = Date()
        let request = UpsertBrewLogRequest(
            beanId: UUID(), methodSlug: "espresso", brewedAt: now.addingTimeInterval(3_600), doseG: 18, waterG: 40
        )
        do {
            _ = try await service.validated(request, userID: UUID(), now: now)
            XCTFail("Expected a validation error")
        } catch let error as AppError {
            XCTAssertEqual(Set(error.fieldErrors?.map(\.field) ?? []), ["brewedAt", "yieldG", "waterG"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNormalizesTextAndFlavorNotes() async throws {
        let brew = try await service.validated(UpsertBrewLogRequest(
            beanId: UUID(), methodSlug: "v60", brewedAt: Date(), doseG: 15, waterG: 250, grindSetting: " ",
            flavorNoteSlugs: ["peach", "jasmine", "peach"], notes: " Sweet "
        ), userID: UUID())
        XCTAssertNil(brew.grindSetting)
        XCTAssertEqual(brew.notes, "Sweet")
        XCTAssertEqual(brew.flavorNoteSlugs, ["peach", "jasmine"])
    }
}

// MARK: - Helpers

final class PeopleServiceTests: XCTestCase {
    func testQueryIsTrimmedAndIgnoresLeadingAt() {
        XCTAssertEqual(PeopleService.normalizedQuery("  @ana  "), "ana")
        XCTAssertEqual(PeopleService.normalizedQuery(nil), "")
    }

    func testEmptySearchDoesNotQuery() async throws {
        let service = PeopleService(people: UnreachablePeopleRepository())
        let results = try await service.search(query: " @ ", viewerID: UUID())
        XCTAssertTrue(results.isEmpty)
    }

    func testCannotFollowYourself() async {
        let service = PeopleService(people: UnreachablePeopleRepository())
        let me = UUID()
        do {
            _ = try await service.follow(memberID: me, followerID: me)
            XCTFail("Expected an error")
        } catch let error as AppError {
            XCTAssertEqual(error.status, .unprocessableEntity)
            XCTAssertEqual(error.code, APIErrorCode.cannotFollowSelf)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLikeWildcardsAreEscaped() {
        XCTAssertEqual(PostgresPeopleRepository.escapedForLike("a_b%c\\"), "a\\_b\\%c\\\\")
    }
}

final class JPEGInfoTests: XCTestCase {
    func testReadsSizeFromFrameHeader() {
        XCTAssertEqual(JPEGInfo.dimensions(of: tinyJPEG(width: 800, height: 600))?.width, 800)
        XCTAssertEqual(JPEGInfo.dimensions(of: tinyJPEG(width: 800, height: 600))?.height, 600)
    }

    func testRejectsOtherData() {
        XCTAssertNil(JPEGInfo.dimensions(of: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])))
        XCTAssertNil(JPEGInfo.dimensions(of: Data([0xFF, 0xD8, 0xFF, 0xD9])))
    }
}

final class PostServiceTests: XCTestCase {
    private let service = PostService(posts: UnreachablePostRepository())

    func testEmptyPostIsRejected() {
        XCTAssertThrowsError(try service.validated(CreatePostRequest(body: "   "))) { error in
            XCTAssertEqual((error as? AppError)?.fieldErrors?.map(\.field), ["body"])
        }
    }

    func testPhotoOnlyPostIsAllowedAndBlankTextDropped() throws {
        let post = try service.validated(CreatePostRequest(body: "  ", mediaIds: [UUID()]))
        XCTAssertNil(post.body)
    }

    func testRepeatedOrTooManyPhotosAreRejected() {
        let id = UUID()
        XCTAssertThrowsError(try service.validated(CreatePostRequest(body: "Hi", mediaIds: [id, id])))
        XCTAssertThrowsError(try service.validated(CreatePostRequest(body: "Hi", mediaIds: (0..<5).map { _ in UUID() })))
    }

    func testCannotShareRecipeAndBeanTogether() {
        XCTAssertThrowsError(try service.validated(CreatePostRequest(recipeId: UUID(), beanId: UUID()))) { error in
            XCTAssertEqual((error as? AppError)?.fieldErrors?.map(\.field), ["beanId"])
        }
    }
}

/// A minimal JPEG: start of image, a JFIF segment, a baseline frame header and end of image.
func tinyJPEG(width: Int, height: Int) -> Data {
    var bytes: [UInt8] = [0xFF, 0xD8]
    bytes += [0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]
    bytes += [0xFF, 0xC0, 0x00, 0x11, 0x08, UInt8(height >> 8), UInt8(height & 0xFF), UInt8(width >> 8), UInt8(width & 0xFF),
              0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01]
    bytes += [0xFF, 0xD9]
    return Data(bytes)
}

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
    func list(scope: RecipeListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<RecipeSummaryDTO> {
        fatalError("Not used in unit tests")
    }
    func find(id: UUID, viewerID: UUID) async throws -> RecipeDTO? { fatalError("Not used in unit tests") }
    func create(authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO { fatalError("Not used in unit tests") }
    func update(id: UUID, authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO? {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, authorID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
    func save(id: UUID, userID: UUID) async throws -> SaveStateDTO? { fatalError("Not used in unit tests") }
    func unsave(id: UUID, userID: UUID) async throws -> SaveStateDTO { fatalError("Not used in unit tests") }
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

struct UnreachableEquipmentRepository: EquipmentRepository {
    func list(ownerID: UUID) async throws -> [EquipmentDTO] { fatalError("Not used in unit tests") }
    func canViewProfile(ownerID: UUID, viewerID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
    func create(ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO {
        fatalError("Not used in unit tests")
    }
    func update(id: UUID, ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO? {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, ownerID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
}

struct UnreachableBrewLogRepository: BrewLogRepository {
    func list(userID: UUID, filter: BrewLogFilter, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<BrewLogDTO> {
        fatalError("Not used in unit tests")
    }
    func find(id: UUID, viewerID: UUID) async throws -> BrewLogDTO? { fatalError("Not used in unit tests") }
    func create(userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO { fatalError("Not used in unit tests") }
    func update(id: UUID, userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO? {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, userID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
}

struct UnreachablePeopleRepository: PeopleRepository {
    func profile(id: UUID, viewerID: UUID) async throws -> UserProfileDTO? { fatalError("Not used in unit tests") }
    func search(prefix: String, viewerID: UUID, limit: Int) async throws -> [UserSummaryDTO] {
        fatalError("Not used in unit tests")
    }
    func follows(of memberID: UUID, kind: FollowListKind, viewerID: UUID, after cursor: PageCursor?, limit: Int)
        async throws -> BrewlyAPI.Page<UserSummaryDTO> {
        fatalError("Not used in unit tests")
    }
    func follow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO? { fatalError("Not used in unit tests") }
    func unfollow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO { fatalError("Not used in unit tests") }
}

struct UnreachablePostRepository: PostRepository {
    func list(scope: PostListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<PostDTO> {
        fatalError("Not used in unit tests")
    }
    func find(id: UUID, viewerID: UUID) async throws -> PostDTO? { fatalError("Not used in unit tests") }
    func create(authorID: UUID, kind: PostKind, _ request: CreatePostRequest) async throws -> PostDTO {
        fatalError("Not used in unit tests")
    }
    func delete(id: UUID, authorID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
    func like(postID: UUID, userID: UUID) async throws -> LikeStateDTO? { fatalError("Not used in unit tests") }
    func unlike(postID: UUID, userID: UUID) async throws -> LikeStateDTO { fatalError("Not used in unit tests") }
    func comments(postID: UUID, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<CommentDTO>? {
        fatalError("Not used in unit tests")
    }
    func addComment(postID: UUID, authorID: UUID, body: String, parentID: UUID?) async throws -> CommentDTO? {
        fatalError("Not used in unit tests")
    }
    func deleteComment(id: UUID, userID: UUID) async throws -> Bool { fatalError("Not used in unit tests") }
}
