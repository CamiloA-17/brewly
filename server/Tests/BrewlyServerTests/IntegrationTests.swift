@testable import BrewlyServer
import BrewlyAPI
import Crypto
import FluentKit
import JWT
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
        guard (ProcessInfo.processInfo.environment["JWT_SECRET"]?.count ?? 0) >= 32 else {
            throw ConfigurationError("Set JWT_SECRET (at least 32 characters) to run integration tests.")
        }
        setenv("DATABASE_URL", url, 1)

        app = try await Application.make(.testing)
        try await configure(app)
        app.passwords.use(.plaintext)
        try await app.db.sql.raw("TRUNCATE users CASCADE").run()
        try await app.db.sql.raw("TRUNCATE auth_challenges").run()
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }

    func testUnconfiguredProvidersReturnServiceUnavailable() async throws {
        app.appConfig.apple = nil
        app.appConfig.googleClientID = nil
        for provider in IdentityProvider.allCases {
            try await expectError(.POST, "v1/auth/challenge", body: AuthChallengeRequest(provider: provider),
                status: .serviceUnavailable, code: APIErrorCode.identityProviderUnavailable)
        }
    }

    func testGoogleHTTPFlowVerifiesProviderTokenAndRejectsReplay() async throws {
        app.appConfig.googleClientID = "google-client"
        let key = ES256PrivateKey()
        let keys = await JWTKeyCollection().add(ecdsa: key, kid: "provider-key")
        let jwks = try Self.providerJWKS(key)
        app.clients.use { app in
            StubProviderClient(eventLoop: app.eventLoopGroup.next()) { request in
                XCTAssertEqual(request.url.string, "https://www.googleapis.com/oauth2/v3/certs")
                return jwks
            }
        }
        let challenge: AuthChallengeResponse = try await send(.POST, "v1/auth/challenge",
            body: AuthChallengeRequest(provider: .google))
        let claims = GoogleIdentityToken(issuer: "https://accounts.google.com", subject: "http-google-subject",
            audience: "google-client", authorizedPresenter: "ios-client", issuedAt: .init(value: Date()),
            expires: .init(value: Date().addingTimeInterval(300)), email: "google@example.com",
            emailVerified: true, nonce: challenge.nonce)
        let token = try await keys.sign(claims, kid: "provider-key")
        let body = FederatedSignInRequest(challengeId: challenge.id, identityToken: token)
        let response: AuthResponse = try await send(.POST, "v1/auth/google", body: body)
        XCTAssertTrue(response.user.needsOnboarding)
        try await expectError(.POST, "v1/auth/google", body: body, status: .unauthorized,
            code: APIErrorCode.invalidCredentials)
    }

    func testAppleHTTPFlowExchangesCodeAndRevokesBeforeAccountDeletion() async throws {
        let key = ES256PrivateKey()
        let config = AppleAuthConfig(clientID: "app.brewly.ios", teamID: "TESTTEAM", keyID: "client-key",
            privateKey: ES256PrivateKey(), encryptionKey: SymmetricKey(size: .bits256))
        app.appConfig.apple = config
        let keys = await JWTKeyCollection().add(ecdsa: key, kid: "provider-key")
        let jwks = try Self.providerJWKS(key)
        let challenge: AuthChallengeResponse = try await send(.POST, "v1/auth/challenge",
            body: AuthChallengeRequest(provider: .apple))
        let claims = AppleIdentityToken(issuer: "https://appleid.apple.com", audience: "app.brewly.ios",
            expires: .init(value: Date().addingTimeInterval(300)), issuedAt: .init(value: Date()),
            subject: "http-apple-subject", nonce: challenge.nonce, email: "relay@example.com", emailVerified: true)
        let token = try await keys.sign(claims, kid: "provider-key")
        app.clients.use { app in
            StubProviderClient(eventLoop: app.eventLoopGroup.next()) { request in
                if request.url.path == "/auth/keys" { return jwks }
                let form = try request.content.decode([String: String].self)
                XCTAssertEqual(request.headers.contentType, .urlEncodedForm)
                XCTAssertEqual(form["client_id"], "app.brewly.ios")
                XCTAssertNotNil(form["client_secret"])
                if request.url.path == "/auth/token" {
                    XCTAssertEqual(form["grant_type"], "authorization_code")
                    XCTAssertEqual(form["code"], "native-code")
                    var response = ClientResponse()
                    try response.content.encode(["id_token": token, "refresh_token": "apple-refresh"], as: .json)
                    return response
                }
                XCTAssertEqual(request.url.path, "/auth/revoke")
                XCTAssertEqual(form["token"], "apple-refresh")
                XCTAssertEqual(form["token_type_hint"], "refresh_token")
                return ClientResponse(status: .ok)
            }
        }
        let response: AuthResponse = try await send(.POST, "v1/auth/apple", body: FederatedSignInRequest(
            challengeId: challenge.id, identityToken: token, authorizationCode: "native-code", firstName: "Ana"))
        let encrypted = try await PostgresFederatedAuthRepository(database: app.db).appleRefreshToken(userID: response.user.id)
        XCTAssertNotEqual(encrypted, "apple-refresh")
        XCTAssertEqual(try ProviderTokenCipher(key: config.encryptionKey).decrypt(encrypted!), "apple-refresh")
        try await expectStatus(.DELETE, "v1/me", token: response.accessToken, status: .noContent)
        let deleted = try await PostgresUserRepository(database: app.db).find(id: response.user.id)
        XCTAssertNil(deleted)
    }

    func testFailedAppleRevocationPreservesAccount() async throws {
        let password = try await register("ana.barista")
        let config = AppleAuthConfig(clientID: "app.brewly.ios", teamID: "TESTTEAM", keyID: "client-key",
            privateKey: ES256PrivateKey(), encryptionKey: SymmetricKey(size: .bits256))
        app.appConfig.apple = config
        let encrypted = try ProviderTokenCipher(key: config.encryptionKey).encrypt("apple-refresh")
        try await app.db.sql.raw("""
            INSERT INTO auth_identities (user_id, provider, subject, provider_refresh_token)
            VALUES (\(bind: password.user.id), 'apple', 'revocation-test', \(bind: encrypted))
            """).run()
        app.clients.use { app in
            StubProviderClient(eventLoop: app.eventLoopGroup.next()) { _ in ClientResponse(status: .internalServerError) }
        }
        try await expectError(.DELETE, "v1/me", token: password.accessToken,
            status: .serviceUnavailable, code: APIErrorCode.identityProviderUnavailable)
        let preserved = try await PostgresUserRepository(database: app.db).find(id: password.user.id)
        XCTAssertNotNil(preserved)
    }

    private static func providerJWKS(_ key: ES256PrivateKey) throws -> ClientResponse {
        let parameters = key.publicKey.parameters!
        let jwk = JWK.ecdsa(.es256, identifier: "provider-key", x: parameters.x, y: parameters.y, curve: .p256)
        var response = ClientResponse(headers: ["Cache-Control": "max-age=300"])
        try response.content.encode(JWKS(keys: [jwk]), as: .json)
        return response
    }

    func testFederatedSignInCreatesOnboardingAndReusesIdentity() async throws {
        let identity = VerifiedIdentity(provider: .google, subject: "google-subject", email: "google@example.com",
            nonce: "server-nonce", firstName: "Ana", lastName: "Rojas")
        let service = federatedService(identity)
        let first = try await service.signIn(federatedRequest(identity), provider: .google)
        XCTAssertTrue(first.user.needsOnboarding)
        XCTAssertEqual(first.user.firstName, "Ana")
        XCTAssertEqual(first.user.email, "google@example.com")
        let second = try await service.signIn(federatedRequest(identity), provider: .google)
        XCTAssertEqual(first.user.id, second.user.id)
        XCTAssertNotEqual(first.refreshToken, second.refreshToken)
        let refreshed: AuthResponse = try await send(.POST, "v1/auth/refresh",
            body: RefreshTokenRequest(refreshToken: second.refreshToken))
        XCTAssertEqual(refreshed.user.id, first.user.id)
        let onboarded: CurrentUserDTO = try await send(.PUT, "v1/me/onboarding", token: first.accessToken,
            body: CompleteOnboardingRequest(firstName: "Ana", lastName: "Rojas",
                birthDate: CalendarDate(year: 1995, month: 4, day: 12), acceptedTerms: true))
        XCTAssertFalse(onboarded.needsOnboarding)
        try await app.db.sql.raw("DELETE FROM users WHERE id = \(bind: first.user.id)").run()
        let remaining = try await app.db.sql.raw("SELECT count(*) AS count FROM auth_identities").first()!
        XCTAssertEqual(try remaining.decode(column: "count", as: Int.self), 0)
    }

    func testFederatedEmailCollisionDoesNotLinkAccounts() async throws {
        let password = try await register("ana.barista")
        let identity = VerifiedIdentity(provider: .google, subject: "different-subject", email: password.user.email,
            nonce: "server-nonce")
        do {
            _ = try await federatedService(identity).signIn(federatedRequest(identity), provider: .google)
            XCTFail("An email collision must not sign in to the password account")
        } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.emailTaken) }
        let remaining = try await app.db.sql.raw("SELECT count(*) AS count FROM auth_identities WHERE provider = 'google'").first()!
        XCTAssertEqual(try remaining.decode(column: "count", as: Int.self), 0)
    }

    func testFederatedChallengesRejectReplayExpiredWrongProviderAndNonce() async throws {
        let identity = VerifiedIdentity(provider: .google, subject: "google-subject", email: "google@example.com", nonce: "server-nonce")
        let repository = PostgresFederatedAuthRepository(database: app.db)
        let service = federatedService(identity)
        let body = try await federatedRequest(identity)
        _ = try await service.signIn(body, provider: .google)
        do {
            _ = try await service.signIn(body, provider: .google)
            XCTFail("A consumed challenge must not issue a second session")
        } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
        let hash = TokenService.hash(refreshToken: identity.nonce)
        let expired = try await repository.createChallenge(provider: .google, nonceHash: hash, expiresAt: Date().addingTimeInterval(-1))
        let wrongProvider = try await repository.createChallenge(provider: .apple, nonceHash: hash, expiresAt: Date().addingTimeInterval(300))
        let wrongNonce = try await repository.createChallenge(provider: .google, nonceHash: TokenService.hash(refreshToken: "other"), expiresAt: Date().addingTimeInterval(300))
        for id in [expired, wrongProvider, wrongNonce] {
            do {
                _ = try await service.signIn(FederatedSignInRequest(challengeId: id, identityToken: "test-token"), provider: .google)
                XCTFail("Invalid challenge must fail")
            } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
        }
    }

    func testConcurrentFirstSignInsResolveOneUser() async throws {
        let identity = VerifiedIdentity(provider: .google, subject: "concurrent-subject", email: "concurrent@example.com", nonce: "server-nonce")
        let repository = PostgresFederatedAuthRepository(database: app.db)
        async let first = repository.resolveUser(identity)
        async let second = repository.resolveUser(identity)
        let ids = try await [first, second]
        XCTAssertEqual(ids[0], ids[1])
    }

    func testAppleSignInStoresRevocableTokenAndPrivateNameHints() async throws {
        let identity = VerifiedIdentity(provider: .apple, subject: "apple-subject", email: "relay@example.com", nonce: "server-nonce")
        var body = try await federatedRequest(identity)
        body.authorizationCode = "test-code"
        body.firstName = "Ana"; body.lastName = "Rojas"
        let response = try await federatedService(identity).signIn(body, provider: .apple)
        XCTAssertTrue(response.user.needsOnboarding)
        XCTAssertEqual(response.user.firstName, "Ana")
        let token = try await PostgresFederatedAuthRepository(database: app.db).appleRefreshToken(userID: response.user.id)
        XCTAssertEqual(token, "encrypted-test-token")
        body = try await federatedRequest(identity)
        body.authorizationCode = "second-code"
        let second = try await federatedService(identity).signIn(body, provider: .apple)
        XCTAssertEqual(second.user.id, response.user.id)
        XCTAssertEqual(second.user.firstName, "Ana")
    }

    private func federatedRequest(_ identity: VerifiedIdentity) async throws -> FederatedSignInRequest {
        let id = try await PostgresFederatedAuthRepository(database: app.db).createChallenge(provider: identity.provider,
            nonceHash: TokenService.hash(refreshToken: identity.nonce), expiresAt: Date().addingTimeInterval(300))
        return FederatedSignInRequest(challengeId: id, identityToken: "test-token")
    }

    private func federatedService(_ identity: VerifiedIdentity) -> FederatedAuthService {
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let config = app.appConfig
        return FederatedAuthService(repository: PostgresFederatedAuthRepository(database: app.db),
            verifier: StubIdentityVerifier(identity: identity),
            auth: AuthService(auth: PostgresAuthRepository(database: app.db), users: PostgresUserRepository(database: app.db),
                passwords: RequestPasswordHashing(request: request),
                tokens: TokenService(keys: app.jwt.keys, accessTokenTTL: config.accessTokenTTL, refreshTokenTTL: config.refreshTokenTTL)))
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
            body: Self.signUp(email: "other@example.com", username: "ana.barista"),
            status: .conflict, code: APIErrorCode.usernameTaken)
        try await expectError(.POST, "v1/auth/register",
            body: Self.signUp(email: "ana.barista@example.com", username: "ana2"),
            status: .conflict, code: APIErrorCode.emailTaken)
        try await expectError(.POST, "v1/auth/register",
            body: RegisterRequest(email: "nope", password: "short", username: "A", firstName: "", lastName: "",
                                  birthDate: nil, acceptedTerms: false),
            status: .unprocessableEntity, code: APIErrorCode.validationFailed)
    }

    func testRegistrationStoresPrivateDetails() async throws {
        let ana = try await register("ana.barista")
        XCTAssertEqual(ana.user.displayName, "Ana Rojas")
        XCTAssertEqual(ana.user.firstName, "Ana")
        XCTAssertEqual(ana.user.birthDate, CalendarDate(year: 1995, month: 4, day: 12))
        XCTAssertFalse(ana.user.needsOnboarding)

        // Too young to sign up.
        let today = CalendarDate.today()
        let tooYoung = CalendarDate(year: today.year - 12, month: 1, day: 1)
        try await expectError(.POST, "v1/auth/register",
            body: Self.signUp(email: "kid@example.com", username: "kid", birthDate: tooYoung),
            status: .unprocessableEntity, code: APIErrorCode.validationFailed)

        // The profile can be edited; another member's profile route remains retired.
        let updated: CurrentUserDTO = try await send(.PATCH, "v1/me", token: ana.accessToken, body: UpdateProfileRequest(
            displayName: "Ana R.", firstName: "Ana María", lastName: "Rojas",
            birthDate: CalendarDate(year: 1995, month: 4, day: 12), countryCode: "de", city: " Berlin "
        ))
        XCTAssertEqual(updated.countryCode, "DE")
        XCTAssertEqual(updated.city, "Berlin")
        XCTAssertEqual(updated.firstName, "Ana María")

        let leo = try await register("leo.roaster")
        try await expectError(.GET, "v1/users/\(ana.user.id)", token: leo.accessToken, status: .notFound)
    }

    func testOnboardingCompletesOlderAccounts() async throws {
        let ana = try await register("ana.barista")
        // Accounts created before personal details were required have none.
        try await app.db.sql.raw("""
            UPDATE users SET first_name = NULL, last_name = NULL, birth_date = NULL,
                             terms_accepted_at = NULL, onboarding_completed_at = NULL
            """).run()
        let before: CurrentUserDTO = try await send(.GET, "v1/me", token: ana.accessToken)
        XCTAssertTrue(before.needsOnboarding)

        try await expectError(.PUT, "v1/me/onboarding", token: ana.accessToken, body: CompleteOnboardingRequest(
            firstName: "Ana", lastName: "Rojas", birthDate: CalendarDate(year: 1995, month: 4, day: 12),
            acceptedTerms: false
        ), status: .unprocessableEntity, code: APIErrorCode.validationFailed)

        let after: CurrentUserDTO = try await send(.PUT, "v1/me/onboarding", token: ana.accessToken,
            body: CompleteOnboardingRequest(
                firstName: "Ana", lastName: "Rojas", birthDate: CalendarDate(year: 1995, month: 4, day: 12),
                acceptedTerms: true
            ))
        XCTAssertFalse(after.needsOnboarding)
        XCTAssertEqual(after.lastName, "Rojas")
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

    // MARK: - Equipment

    func testEquipmentDefaultsSettingsAndPrivacy() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")

        let c40: EquipmentDTO = try await send(.POST, "v1/me/equipment", token: ana.accessToken,
            body: UpsertEquipmentRequest(
                kind: .grinder, grinderSlug: "comandante_c40_mk4", isDefault: true,
                grindSettings: [GrindSettingInput(methodSlug: "v60", grindSetting: "24 clicks")]
            ))
        XCTAssertTrue(c40.isDefault)
        XCTAssertEqual(c40.grindSettings, [GrindSettingInput(methodSlug: "v60", grindSetting: "24 clicks")])

        // A new default grinder replaces the previous one.
        let k6: EquipmentDTO = try await send(.POST, "v1/me/equipment", token: ana.accessToken,
            body: UpsertEquipmentRequest(kind: .grinder, brand: "Kingrinder", model: "K6", isDefault: true))
        let _: EquipmentDTO = try await send(.POST, "v1/me/equipment", token: ana.accessToken,
            body: UpsertEquipmentRequest(kind: .kettle, brand: "Fellow", model: "Stagg EKG", isDefault: true))
        let mine: [EquipmentDTO] = try await send(.GET, "v1/me/equipment", token: ana.accessToken)
        XCTAssertEqual(mine.filter(\.isDefault).map(\.kind), [.grinder, .kettle])
        XCTAssertEqual(mine.first { $0.isDefault && $0.kind == .grinder }?.id, k6.id)

        // Unknown catalog references and other members' items.
        try await expectError(.POST, "v1/me/equipment", token: ana.accessToken,
            body: UpsertEquipmentRequest(kind: .grinder, grinderSlug: "teapot"),
            status: .unprocessableEntity, code: APIErrorCode.validationFailed)
        try await expectError(.PUT, "v1/me/equipment/\(c40.id)", token: leo.accessToken,
            body: UpsertEquipmentRequest(kind: .grinder, brand: "Stolen"), status: .notFound)

        // Only the owner can access their gear; member profile routes remain retired.
        try await expectError(.GET, "v1/users/\(ana.user.id)/equipment", token: leo.accessToken, status: .notFound)

        try await expectStatus(.DELETE, "v1/me/equipment/\(c40.id)", token: ana.accessToken, status: .noContent)
        let remaining: [EquipmentDTO] = try await send(.GET, "v1/me/equipment", token: ana.accessToken)
        XCTAssertEqual(remaining.count, 2)
    }

    // MARK: - Beans and recipes

    func testBrewSessionsKeepHistoryPrivateAndIndependentOfRecipeEdits() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.barista")
        let bean: BeanDTO = try await send(.POST, "v1/beans", token: ana.accessToken, body: Self.geisha)
        let recipe: RecipeDTO = try await send(.POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id))

        let body = CreateBrewSessionRequest(
            recipeId: recipe.id, doseG: 15, waterG: 250, yieldG: 215,
            grindSetting: "24 clicks", waterTempC: 93, elapsedS: 185, tdsPercent: 1.38,
            rating: 4, acidity: 3, bitterness: 1, body: 3, notes: "Floral"
        )
        try await expectError(.POST, "v1/me/brew-sessions", token: leo.accessToken,
                              body: body, status: .notFound)
        let session: BrewSessionDTO = try await send(.POST, "v1/me/brew-sessions", token: ana.accessToken, body: body)
        XCTAssertEqual(session.recipeTitle, recipe.title)
        XCTAssertEqual(session.elapsedS, 185)
        XCTAssertEqual(session.extractionYieldPercent, 19.78)
        var invalid = body
        invalid.acidity = 6
        let validation = try await expectError(.POST, "v1/me/brew-sessions", token: ana.accessToken,
                                               body: invalid, status: .unprocessableEntity)
        XCTAssertEqual(validation.fieldErrors?.first?.field, "acidity")
        let second: BrewSessionDTO = try await send(.POST, "v1/me/brew-sessions", token: ana.accessToken, body: body)
        let firstPage: BrewlyAPI.Page<BrewSessionDTO> = try await send(
            .GET, "v1/me/brew-sessions?limit=1", token: ana.accessToken
        )
        XCTAssertEqual(firstPage.items.map(\.id), [second.id])
        let cursor = try XCTUnwrap(firstPage.nextCursor)
        let nextPage: BrewlyAPI.Page<BrewSessionDTO> = try await send(
            .GET, "v1/me/brew-sessions?limit=1&cursor=\(cursor)", token: ana.accessToken
        )
        XCTAssertEqual(nextPage.items.map(\.id), [session.id])
        let otherHistory: BrewlyAPI.Page<BrewSessionDTO> = try await send(.GET, "v1/me/brew-sessions", token: leo.accessToken)
        XCTAssertTrue(otherHistory.items.isEmpty)

        var edit = Self.v60(beanID: bean.id)
        edit.title = "Revised plan"
        let _: RecipeDTO = try await send(.PUT, "v1/recipes/\(recipe.id)", token: ana.accessToken, body: edit)
        let history: BrewlyAPI.Page<BrewSessionDTO> = try await send(
            .GET, "v1/me/brew-sessions?recipeId=\(recipe.id)", token: ana.accessToken
        )
        XCTAssertEqual(history.items.first?.recipeTitle, recipe.title)
    }

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
        XCTAssertEqual(bean.visibility, .private)
        try await expectError(.GET, "v1/beans/\(bean.id)", token: leo.accessToken, status: .notFound)

        let privateRecipe: RecipeDTO = try await send(
            .POST, "v1/recipes", token: ana.accessToken, body: Self.v60(beanID: bean.id)
        )
        XCTAssertEqual(privateRecipe.visibility, .private)

        try await expectError(.GET, "v1/recipes/\(privateRecipe.id)", token: leo.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/recipes/\(privateRecipe.id)", token: leo.accessToken,
                              body: Self.v60(beanID: bean.id), status: .notFound)
        try await expectError(.DELETE, "v1/recipes/\(privateRecipe.id)", token: leo.accessToken, status: .notFound)

        // Leo cannot brew with Ana's bean.
        let error = try await expectError(.POST, "v1/recipes", token: leo.accessToken,
                                          body: Self.v60(beanID: bean.id), status: .unprocessableEntity)
        XCTAssertEqual(error.fieldErrors?.map(\.field), ["beanId"])

        try await expectStatus(.GET, "v1/recipes", token: leo.accessToken, status: .notFound)

        var remix = Self.v60(beanID: bean.id)
        remix.forkedFromId = privateRecipe.id
        let retired = try await expectError(
            .POST, "v1/recipes", token: ana.accessToken, body: remix,
            status: .unprocessableEntity, code: APIErrorCode.validationFailed
        )
        XCTAssertEqual(retired.fieldErrors?.map(\.field), ["forkedFromId"])
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

    func testSocialRoutesAreRetired() async throws {
        let ana = try await register("ana.barista")
        try await expectStatus(.GET, "v1/feed", token: ana.accessToken, status: .notFound)
        try await expectStatus(.GET, "v1/users", token: ana.accessToken, status: .notFound)
        try await expectStatus(.GET, "v1/posts/explore", token: ana.accessToken, status: .notFound)
        try await expectStatus(.GET, "v1/me/notifications", token: ana.accessToken, status: .notFound)
        try await expectStatus(.GET, "v1/me/saved-recipes", token: ana.accessToken, status: .notFound)
    }

    // MARK: - Media

    func testAvatar() async throws {
        let ana = try await register("ana.barista")
        let leo = try await register("leo.roaster")
        let first = try await upload(tinyJPEG(width: 400, height: 400), token: ana.accessToken)
        let updated: CurrentUserDTO = try await send(.PUT, "v1/me/avatar", token: ana.accessToken,
            body: UpdateAvatarRequest(mediaId: first.id))
        XCTAssertEqual(updated.avatarURL, first.url)
        // Avatars are visible to everyone.
        try await expectStatus(.GET, "v1/media/\(first.id)", token: leo.accessToken, status: .ok)

        // Replacing the avatar deletes the previous image; others' images can't be used.
        let second = try await upload(tinyJPEG(width: 400, height: 400), token: ana.accessToken)
        let _: CurrentUserDTO = try await send(.PUT, "v1/me/avatar", token: ana.accessToken,
            body: UpdateAvatarRequest(mediaId: second.id))
        try await expectError(.GET, "v1/media/\(first.id)", token: ana.accessToken, status: .notFound)
        try await expectError(.PUT, "v1/me/avatar", token: leo.accessToken,
            body: UpdateAvatarRequest(mediaId: second.id), status: .unprocessableEntity)

        let removed: CurrentUserDTO = try await send(.DELETE, "v1/me/avatar", token: ana.accessToken)
        XCTAssertNil(removed.avatarURL)
    }

    func testUploadsMustBeJPEG() async throws {
        let ana = try await register("ana.barista")
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: ana.accessToken)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: [0x89, 0x50, 0x4E, 0x47])
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unprocessableEntity)
        })
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: ana.accessToken)
            req.headers.contentType = .png
            req.body = ByteBuffer(bytes: Array(tinyJPEG(width: 10, height: 10)))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unsupportedMediaType)
        })
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
        try await send(.POST, "v1/auth/register", body: Self.signUp(email: "\(username)@example.com", username: username))
    }

    private static func signUp(
        email: String,
        username: String,
        birthDate: CalendarDate? = CalendarDate(year: 1995, month: 4, day: 12)
    ) -> RegisterRequest {
        RegisterRequest(
            email: email, password: "test-password", username: username, firstName: "Ana", lastName: "Rojas",
            birthDate: birthDate, acceptedTerms: true
        )
    }

    private func upload(_ jpeg: Data, token: String, file: StaticString = #filePath, line: UInt = #line) async throws -> MediaDTO {
        var media: MediaDTO?
        try await app.test(.POST, "v1/media", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: Array(jpeg))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created, res.body.string, file: file, line: line)
            media = try res.content.decode(MediaDTO.self, using: BrewlyJSON.makeDecoder())
        })
        return try XCTUnwrap(media, file: file, line: line)
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

private struct StubIdentityVerifier: IdentityTokenVerifying {
    let identity: VerifiedIdentity
    func requireConfiguration(provider: IdentityProvider) throws {}
    func verify(_ token: String, provider: IdentityProvider) async throws -> VerifiedIdentity { identity }
    func exchangeAppleCode(_ code: String, identity: VerifiedIdentity) async throws -> String { "encrypted-test-token" }
}

private struct StubProviderClient: Client {
    let eventLoop: EventLoop
    let respond: @Sendable (ClientRequest) throws -> ClientResponse
    func delegating(to eventLoop: EventLoop) -> Client { StubProviderClient(eventLoop: eventLoop, respond: respond) }
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        do { return eventLoop.makeSucceededFuture(try respond(request)) }
        catch { return eventLoop.makeFailedFuture(error) }
    }
}
