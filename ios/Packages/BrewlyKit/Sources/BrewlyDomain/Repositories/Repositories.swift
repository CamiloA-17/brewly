import Foundation

// Contratos que la capa de presentación usa. La implementación real vive en
// `BrewlyData` (Supabase) y existe una versión en memoria para previews y tests.

public enum AuthState: Equatable, Sendable {
    case loading
    case signedOut
    case signedIn(userID: UUID)
}

public protocol AuthRepository: Sendable {
    var currentUserID: UUID? { get async }
    /// Emite cada cambio de sesión (incluido el estado inicial).
    func authStates() -> AsyncStream<AuthState>
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, username: String) async throws
    /// Sign in with Apple: `idToken` y `nonce` provienen de AuthenticationServices.
    func signInWithApple(idToken: String, nonce: String) async throws
    func signOut() async throws
}

public protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
    func profile(username: String) async throws -> Profile?
    func search(_ query: String) async throws -> [Profile]
    func updateMyProfile(_ update: ProfileUpdate) async throws -> Profile
    /// Sube la imagen JPEG y devuelve la ruta guardada en `avatar_path`.
    func uploadAvatar(_ jpegData: Data) async throws -> String
    func publicAvatarURL(path: String) -> URL?
}

public protocol CoffeeRepository: Sendable {
    func beans(includeArchived: Bool) async throws -> [CoffeeBean]
    func saveBean(_ bean: CoffeeBean) async throws -> CoffeeBean
    func deleteBean(id: UUID) async throws
    func bags(beanID: UUID?) async throws -> [BeanBag]
    func saveBag(_ bag: BeanBag) async throws -> BeanBag
    func deleteBag(id: UUID) async throws
    func equipment() async throws -> [Equipment]
    func saveEquipment(_ item: Equipment) async throws -> Equipment
    func brewMethods() async throws -> [BrewMethod]
}

public protocol RecipeRepository: Sendable {
    func myRecipes() async throws -> [Recipe]
    func recipe(id: UUID) async throws -> Recipe
    /// Crea o actualiza la receta y reemplaza sus pasos.
    func save(_ recipe: Recipe) async throws -> Recipe
    func delete(id: UUID) async throws
    /// Copia la receta de otra persona como receta privada propia.
    func fork(id: UUID) async throws -> Recipe
}

public protocol BrewRepository: Sendable {
    func myBrews(limit: Int) async throws -> [Brew]
    func save(_ brew: Brew) async throws -> Brew
    func delete(id: UUID) async throws
    func stats(days: Int) async throws -> BrewStats
}

public struct PublishRequest: Sendable {
    public var kind: PostKind
    public var contentID: UUID?
    public var caption: String?
    public var visibility: Visibility
    public var commentsEnabled: Bool
    /// Imágenes JPEG ya comprimidas, en orden.
    public var images: [Data]

    public init(
        kind: PostKind,
        contentID: UUID?,
        caption: String?,
        visibility: Visibility = .public,
        commentsEnabled: Bool = true,
        images: [Data] = []
    ) {
        self.kind = kind
        self.contentID = contentID
        self.caption = caption
        self.visibility = visibility
        self.commentsEnabled = commentsEnabled
        self.images = images
    }
}

public protocol SocialRepository: Sendable {
    func homeFeed(after cursor: FeedCursor?, limit: Int) async throws -> [Post]
    func exploreFeed(offset: Int, limit: Int, kind: PostKind?) async throws -> [Post]
    func posts(authorID: UUID, after cursor: FeedCursor?, limit: Int) async throws -> [Post]
    func savedPosts() async throws -> [Post]
    func publish(_ request: PublishRequest) async throws -> Post
    func deletePost(id: UUID) async throws
    func setLiked(_ liked: Bool, postID: UUID) async throws
    func setSaved(_ saved: Bool, postID: UUID) async throws
    func comments(postID: UUID) async throws -> [Comment]
    func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> Comment
    func deleteComment(id: UUID) async throws
    /// URL (firmada si el bucket es privado) para mostrar un archivo del post.
    func mediaURL(for media: PostMedia) async throws -> URL
}

public protocol RelationshipRepository: Sendable {
    func follow(userID: UUID) async throws -> FollowStatus
    func unfollow(userID: UUID) async throws
    func pendingRequests() async throws -> [Profile]
    func respond(toRequestFrom userID: UUID, accept: Bool) async throws
    func followers(of userID: UUID) async throws -> [Profile]
    func following(of userID: UUID) async throws -> [Profile]
    func block(userID: UUID) async throws
    func unblock(userID: UUID) async throws
}

public protocol NotificationRepository: Sendable {
    func notifications(limit: Int) async throws -> [AppNotification]
    func unreadCount() async throws -> Int
    func markAllAsRead() async throws
    func registerPushToken(_ token: String) async throws
    /// Emite cuando llega una notificación nueva en tiempo real.
    func liveNotifications() -> AsyncStream<Void>
}

/// Contenedor de dependencias que se inyecta en la capa de presentación.
public struct AppDependencies: Sendable {
    public var auth: any AuthRepository
    public var profiles: any ProfileRepository
    public var coffee: any CoffeeRepository
    public var recipes: any RecipeRepository
    public var brews: any BrewRepository
    public var social: any SocialRepository
    public var relationships: any RelationshipRepository
    public var notifications: any NotificationRepository

    public init(
        auth: any AuthRepository,
        profiles: any ProfileRepository,
        coffee: any CoffeeRepository,
        recipes: any RecipeRepository,
        brews: any BrewRepository,
        social: any SocialRepository,
        relationships: any RelationshipRepository,
        notifications: any NotificationRepository
    ) {
        self.auth = auth
        self.profiles = profiles
        self.coffee = coffee
        self.recipes = recipes
        self.brews = brews
        self.social = social
        self.relationships = relationships
        self.notifications = notifications
    }
}

public enum BrewlyError: LocalizedError, Equatable, Sendable {
    case notAuthenticated
    case notFound
    case validation(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Debes iniciar sesión."
        case .notFound: "No se encontró el elemento."
        case .validation(let message): message
        }
    }
}
