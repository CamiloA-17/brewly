@testable import BrewlyServer
import BrewlyAPI
import FluentKit
import SQLKit
import XCTVapor

/// End-to-end tests against a real, migrated PostgreSQL database.
///
/// They run only when `TEST_DATABASE_URL` is set, because every test truncates all user data.
/// Tokens are signed with the `JWT_SECRET` of the environment (`make server-test` loads it from `.env`):
///
///     TEST_DATABASE_URL=postgres://<user>:<password>@localhost:5432/brewly_test make server-test
final class IntegrationTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        guard let url = ProcessInfo.processInfo.environment["TEST_DATABASE_URL"], !url.isEmpty else {
            throw XCTSkip("Set TEST_DATABASE_URL to run integration tests.")
        }
        guard let secret = ProcessInfo.processInfo.environment["JWT_SECRET"], secret.count >= 32 else {
            throw ConfigurationError("Set JWT_SECRET (at least 32 characters) to run integration tests.")
        }
        setenv("DATABASE_URL", url, 1)

        app = try await Application.make(.testing)
        try await configure(app)
        app.passwords.use(.plaintext)
        try await app.db.sql.raw("TRUNCATE users CASCADE").run()
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }

    // MARK: - Auth

    func testRegisterLoginRefreshAndLogout() async throws {
        let registered = try await register("ana.barista")
        XCTAssertEqual(registered.user.username, "ana.barista")
        XCTAssertEqual(registered.user.email, "ana.barista@example.com")

        let loggedIn: AuthResponse = try await send(.POST, "v1/auth/login",
            body: LoginRequest(email: "ANA.BARISTA@example.com", password: "test-password"))
        XCTAssertEqual(loggedIn.user.id, registered.user.id)

        try await expectError(.POST, "v1/auth/login",
            body: LoginRequest(email: "ana.barista@example.com", password: "wrong-password"),
            status: .unauthorized, code: APIErrorCode.invalidCredentials)

        let refreshed: AuthResponse = try await send(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: loggedIn.refreshToken))
        XCTAssertNotEqual(refreshed.refreshToken, loggedIn.refreshToken)

        // A consumed refresh token cannot be reused, and reusing it revokes the session.
        try await expectError(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: loggedIn.refreshToken), status: .unauthorized)
        try await expectError(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: refreshed.refreshToken), status: .unauthorized)
    }

    func testRegistrationConflictsAndValidation() async throws {
        _ = try await register("ana.barista")
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "other@example.com", password: "test-password", username: "ana.barista", displayName: "Ana"),
            status: .conflict, code: APIErrorCode.usernameTaken)
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "ana.barista@example.com", password: "test-password", username: "ana2", displayName: "Ana"),
            status: .conflict, code: APIErrorCode.emailTaken)
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "nope", password: "short", username: "A", displayName: ""),
            status: .unprocessableEntity, code: APIErrorCode.validationFailed)
    }

    func testProtectedRoutesRequireAToken() async throws {
        try await expectError(.GET, "v1/me", status: .unauthorized, code: APIErrorCode.unauthorized)
    }

    // MARK: - Catalog and methods

    func testCatalogAndMyMethods() async throws {
        let ana = try await register("ana.barista")
        let catalog: CatalogDTO = try await send(.GET, "v1/catalog", token: ana.accessToken)
        XCTAssertTrue(catalog.brewMethods.contains { $0.slug == "espresso" && $0.ratioBasis == .beverage })
        XCTAssertFalse(catalog.varietals.isEmpty)
        XCTAssertFalse(catalog.countries.isEmpty)

        try await expectStatus(.PUT, "v1/me/methods/v60", token: ana.accessToken, status: .noContent)
        try await expectStatus(.PUT, "v1/me/methods/v60", token: ana.accessToken, status: .noContent)
        try await expectError(.PUT, "v1/me/methods/teapot", token: ana.accessToken, status: .notFound)
        let methods: UserMethodsDTO = try await send(.GET, "v1/me/methods", token: ana.accessToken)
        XCTAssertEqual(methods.methodSlugs, ["v60"])
    }

    // MARK: - Beans and recipes

    func testBeanAndRecipeLifecycle() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        XCTAssertEqual(bean.varietalSlugs, ["geisha"])
        XCTAssertEqual(bean.roastDate, CalendarDate(year: 2026, month: 9, day: 1))

        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))
        XCTAssertEqual(recipe.ratio, 16.67)
        XCTAssertEqual(recipe.extractionYieldPercent, 19.78)
        XCTAssertEqual(recipe.steps.map(\.position), [1, 2])
        XCTAssertEqual(recipe.bean.id, bean.id)

        let mine: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/me/recipes", token: ana.accessToken)
        XCTAssertEqual(mine.items.map(\.id), [recipe.id])

        var edit = Self.v60(beanID: bean.id)
        edit.title = "Floral V60 v2"
        edit.steps = []
        let updated: RecipeDTO = try await send(.PUT, "v1/recipes/\(recipe.id)", token: ana.accessToken, body: edit)
        XCTAssertEqual(updated.title, "Floral V60 v2")
        XCTAssertTrue(updated.steps.isEmpty)

        // A bean used by a recipe cannot be deleted, but it can be archived.
        try await expectError(.DELETE, "v1/beans/\(bean.id)", token: ana.accessToken,
                              status: .conflict, code: APIErrorCode.beanInUse)
        var archive = Self.geisha
        archive.isArchived = true
        let archived: BeanDTO = try await send(.PUT, "v1/beans/\(bean.id)", token: ana.accessToken, body: archive)
        XCTAssertTrue(archived.isArchived)
        let active: [BeanDTO] = try await send(.GET, "v1/me/beans", token: ana.accessToken)
        XCTAssertTrue(active.isEmpty)
        let all: [BeanDTO] = try await send(.GET, "v1/me/beans?includeArchived=true", token: ana.accessToken)
        XCTAssertEqual(all.count, 1)

        try await expectStatus(.DELETE, "v1/recipes/\(recipe.id)", token: ana.accessToken, status: .noContent)
        try await expectStatus(.DELETE, "v1/beans/\(bean.id)", token: ana.accessToken, status: .noContent)
    }

    func testRecipeValidationUsesTheMethodRatioBasis() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)

        var espresso = Self.v60(beanID: bean.id)
        espresso.methodSlug = "espresso"
        let error = try await expectError(.POST, "v1/recipes", token: ana.accessToken, body: espresso,
                                          status: .unprocessableEntity, code: APIErrorCode.validationFailed)
        XCTAssertEqual(Set(error.fieldErrors?.map(\.field) ?? []), ["waterG"])

        espresso.waterG = nil
        espresso.yieldG = 36
        espresso.tdsPercent = 9
        let shot: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: espresso)
        XCTAssertEqual(shot.ratio, 2.4)
    }

    func testOwnershipAndVisibility() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)

        var privateRecipe = Self.v60(beanID: bean.id)
        privateRecipe.visibility = .private
        let hidden: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: privateRecipe)
        let shared: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        try await expectError(.GET, "v1/recipes/\(hidden.id)", token: leo.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/recipes/\(shared.id)", token: leo.accessToken,
                              body: Self.v60(beanID: bean.id), status: .notFound)
        try await expectError(.DELETE, "v1/recipes/\(shared.id)", token: leo.accessToken, status: .notFound)

        // Leo cannot brew with Ana's bean.
        let error = try await expectError(.POST, "v1/recipes", token: leo.accessToken,
                                          body: Self.v60(beanID: bean.id), status: .unprocessableEntity)
        XCTAssertEqual(error.fieldErrors?.map(\.field), ["beanId"])

        let explore: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?method=v60&country=co", token: leo.accessToken)
        XCTAssertEqual(explore.items.map(\.id), [shared.id])
    }

    func testExplorePagination() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        var created: [UUID] = []
        for _ in 0..<3 {
            let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))
            created.append(recipe.id)
        }
        let first: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?limit=2", token: ana.accessToken)
        XCTAssertEqual(first.items.count, 2)
        let cursor = try XCTUnwrap(first.nextCursor)
        let second: BrewlyAPI.Page<RecipeSummaryDTO> = try await send(.GET, "v1/recipes?limit=2&cursor=\(cursor)", token: ana.accessToken)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertNil(second.nextCursor)
        XCTAssertEqual(Set((first.items + second.items).map(\.id)), Set(created))
    }

    func testDeleteAccountRemovesEverything() async throws {
        let ana = try await register("ana.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let _: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        try await expectStatus(.DELETE, "v1/me", token: ana.accessToken, status: .noContent)
        try await expectError(.GET, "v1/me", token: ana.accessToken, status: .unauthorized)
        let remaining = try await app.db.sql.raw("SELECT count(*) AS count FROM recipes").first()
        XCTAssertEqual(try remaining?.decode(column: "count", as: Int.self), 0)
    }

    // MARK: - Fixtures

    private static let geisha = UpsertBeanRequest(
        name: "Geisha Washed",
        roaster: "Demo Roasters",
        countryCode: "CO",
        farm: "Finca Las Nubes",
        altitudeMinM: 1750,
        altitudeMaxM: 1900,
        processingMethodSlug: "washed",
        varietalSlugs: ["geisha"],
        flavorNoteSlugs: ["jasmine"],
        roastLevel: .light,
        roastDate: CalendarDate(year: 2026, month: 9, day: 1)
    )

    private static func v60(beanID: UUID) -> UpsertRecipeRequest {
        UpsertRecipeRequest(
            beanId: beanID,
            methodSlug: "v60",
            title: "Floral V60",
            doseG: 15,
            waterG: 250,
            yieldG: 215,
            grindSize: .mediumFine,
            grinderSlug: "comandante_c40_mk4",
            grindSetting: "24 clicks",
            waterTempC: 93,
            bloomWaterG: 45,
            bloomTimeS: 45,
            totalTimeS: 180,
            filterType: .paper,
            tdsPercent: 1.38,
            rating: 5,
            flavorNoteSlugs: ["jasmine", "peach"],
            steps: [
                RecipeStepInput(kind: .bloom, startS: 0, waterTargetG: 45, instruction: "Bloom"),
                RecipeStepInput(kind: .pour, startS: 45, waterTargetG: 250),
            ]
        )
    }

    // MARK: - HTTP helpers

    private struct Empty: Encodable {}

    private func register(_ username: String) async throws -> AuthResponse {
        try await send(.POST, "v1/auth/register", body: RegisterRequest(
            email: "\(username)@example.com", password: "test-password", username: username, displayName: username
        ))
    }

    private func send<Output: Decodable>(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        body: (some Encodable)? = Empty?.none,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> Output {
        var decoded: Output?
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: body)
        }, afterResponse: { res in
            XCTAssertLessThan(res.status.code, 300, "\(method) \(path): \(res.body.string)", file: file, line: line)
            decoded = try res.content.decode(Output.self, using: BrewlyJSON.makeDecoder())
        })
        return try XCTUnwrap(decoded, file: file, line: line)
    }

    private func expectStatus(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        status: HTTPResponseStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: Empty?.none)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, status, res.body.string, file: file, line: line)
        })
    }

    @discardableResult
    private func expectError(
        _ method: HTTPMethod,
        _ path: String,
        token: String? = nil,
        body: (some Encodable)? = Empty?.none,
        status: HTTPResponseStatus,
        code: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> APIErrorResponse {
        var decoded: APIErrorResponse?
        try await app.test(method, path, beforeRequest: { req in
            try Self.prepare(&req, token: token, body: body)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, status, res.body.string, file: file, line: line)
            decoded = try res.content.decode(APIErrorResponse.self, using: BrewlyJSON.makeDecoder())
        })
        let error = try XCTUnwrap(decoded, file: file, line: line)
        if let code {
            XCTAssertEqual(error.code, code, file: file, line: line)
        }
        return error
    }

    private static func prepare(_ req: inout XCTHTTPRequest, token: String?, body: (some Encodable)?) throws {
        if let token {
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
        }
        if let body {
            try req.content.encode(body, using: BrewlyJSON.makeEncoder())
        }
    }
}
