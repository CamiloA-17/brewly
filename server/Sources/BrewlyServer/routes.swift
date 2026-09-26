import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: HealthController())

    let v1 = app.grouped("v1")
    try v1.register(collection: AuthController())

    // Everything below requires a valid access token.
    let authenticated = v1.grouped(AccessTokenAuthenticator(), AuthenticatedUser.guardMiddleware())
    try authenticated.register(collection: MeController())
    try authenticated.register(collection: CatalogController())
    try authenticated.register(collection: BeanController())
    try authenticated.register(collection: RecipeController())
    try authenticated.register(collection: PeopleController())
    try authenticated.register(collection: MediaController())
    try authenticated.register(collection: PostController())
    try authenticated.register(collection: NotificationController())
    try authenticated.register(collection: EquipmentController())
}
