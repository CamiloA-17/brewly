import BrewlyDomain
import Foundation

/// Backend en memoria para SwiftUI Previews y pruebas de UI. No persiste nada
/// y no aplica reglas de privacidad: esas viven y se prueban en la base de datos.
public actor PreviewBackend {
    public static let dependencies: AppDependencies = {
        let backend = PreviewBackend()
        return AppDependencies(
            auth: backend, profiles: backend, coffee: backend, recipes: backend,
            brews: backend, social: backend, relationships: backend, notifications: backend
        )
    }()

    public nonisolated let me: Profile
    let v60: BrewMethod
    let espresso: BrewMethod

    var beans: [CoffeeBean]
    var bags: [BeanBag]
    var recipes: [Recipe]
    var brews: [Brew] = []
    var posts: [Post] = []
    var comments: [Comment] = []
    var equipmentItems: [Equipment] = []

    public init() {
        let me = Profile(id: UUID(), username: "barista", displayName: "Barista Demo", role: .barista)
        let v60 = BrewMethod(slug: "v60", name: "Hario V60", category: .pourOver, icon: "drop.fill",
                             defaultParams: .init(doseG: 15, waterG: 250, tempC: 94, timeS: 180))
        let espresso = BrewMethod(slug: "espresso", name: "Espresso", category: .espresso, icon: "cup.and.saucer.fill",
                                  defaultParams: .init(doseG: 18, yieldG: 36, tempC: 93, timeS: 28))
        let bean = CoffeeBean(ownerID: me.id, name: "Huila Geisha", roaster: "Tostador Demo",
                              originCountry: "Colombia", region: "Huila", process: .washed,
                              roastLevel: .light, tastingNotes: ["jazmín", "durazno", "panela"])
        let recipe = Recipe(
            ownerID: me.id, title: "V60 dulce y limpio", brewMethodID: v60.id, beanID: bean.id,
            doseG: 15, waterG: 250, waterTempC: 94, grindSetting: "Comandante 24", totalTimeS: 180,
            visibility: .public, method: v60, bean: bean,
            steps: [
                RecipeStep(position: 0, kind: .bloom, instruction: "Bloom con 45 g y remover", waterG: 45, startAtS: 0, durationS: 45),
                RecipeStep(position: 1, kind: .pour, instruction: "Verter en espiral hasta 150 g", waterG: 105, startAtS: 45, durationS: 30),
                RecipeStep(position: 2, kind: .pour, instruction: "Verter hasta 250 g", waterG: 100, startAtS: 90, durationS: 30),
                RecipeStep(position: 3, kind: .swirl, instruction: "Girar suavemente y dejar drenar", startAtS: 120, durationS: 60),
            ]
        )
        self.me = me
        self.v60 = v60
        self.espresso = espresso
        self.beans = [bean]
        self.bags = [BeanBag(beanID: bean.id, ownerID: me.id, roastDate: .now.addingTimeInterval(-10 * 86_400), weightG: 250, remainingG: 190)]
        self.recipes = [recipe]
        self.posts = [Post(authorID: me.id, kind: .recipe, caption: "Mi receta de la semana ☕️",
                           likeCount: 12, commentCount: 3, author: me, recipe: recipe)]
    }
}

extension PreviewBackend: AuthRepository {
    public var currentUserID: UUID? { me.id }
    public nonisolated func authStates() -> AsyncStream<AuthState> {
        AsyncStream { $0.yield(.signedIn(userID: me.id)) }
    }
    public func signIn(email: String, password: String) async throws {}
    public func signUp(email: String, password: String, username: String) async throws {}
    public func signInWithApple(idToken: String, nonce: String) async throws {}
    public func signOut() async throws {}
}

extension PreviewBackend: ProfileRepository {
    public func profile(id: UUID) async throws -> Profile { me }
    public func profile(username: String) async throws -> Profile? { me }
    public func search(_ query: String) async throws -> [Profile] { [me] }
    public func updateMyProfile(_ update: ProfileUpdate) async throws -> Profile { me }
    public func uploadAvatar(_ jpegData: Data) async throws -> String { "" }
    public nonisolated func publicAvatarURL(path: String) -> URL? { nil }
}

extension PreviewBackend: CoffeeRepository {
    public func beans(includeArchived: Bool) async throws -> [CoffeeBean] { beans }
    public func saveBean(_ bean: CoffeeBean) async throws -> CoffeeBean {
        beans.removeAll { $0.id == bean.id }
        beans.insert(bean, at: 0)
        return bean
    }
    public func deleteBean(id: UUID) async throws { beans.removeAll { $0.id == id } }
    public func bags(beanID: UUID?) async throws -> [BeanBag] {
        bags.filter { beanID == nil || $0.beanID == beanID }
    }
    public func saveBag(_ bag: BeanBag) async throws -> BeanBag {
        bags.removeAll { $0.id == bag.id }
        bags.append(bag)
        return bag
    }
    public func deleteBag(id: UUID) async throws { bags.removeAll { $0.id == id } }
    public func equipment() async throws -> [Equipment] { equipmentItems }
    public func saveEquipment(_ item: Equipment) async throws -> Equipment {
        equipmentItems.removeAll { $0.id == item.id }
        equipmentItems.append(item)
        return item
    }
    public func brewMethods() async throws -> [BrewMethod] { [espresso, v60] }
}

extension PreviewBackend: RecipeRepository {
    public func myRecipes() async throws -> [Recipe] { recipes }
    public func recipe(id: UUID) async throws -> Recipe {
        guard let recipe = recipes.first(where: { $0.id == id }) else { throw BrewlyError.notFound }
        return recipe
    }
    public func save(_ recipe: Recipe) async throws -> Recipe {
        var recipe = recipe
        recipe.ratio = recipe.computedRatio
        recipes.removeAll { $0.id == recipe.id }
        recipes.insert(recipe, at: 0)
        return recipe
    }
    /// Satisface `RecipeRepository.delete` y `BrewRepository.delete` (misma firma).
    public func delete(id: UUID) async throws {
        recipes.removeAll { $0.id == id }
        brews.removeAll { $0.id == id }
    }
    public func fork(id: UUID) async throws -> Recipe {
        var copy = try await recipe(id: id)
        copy.id = UUID()
        copy.forkedFromID = id
        copy.visibility = .private
        recipes.insert(copy, at: 0)
        return copy
    }
}

extension PreviewBackend: BrewRepository {
    public func myBrews(limit: Int) async throws -> [Brew] { Array(brews.prefix(limit)) }
    public func save(_ brew: Brew) async throws -> Brew {
        brews.removeAll { $0.id == brew.id }
        brews.insert(brew, at: 0)
        return brew
    }
    public func stats(days: Int) async throws -> BrewStats {
        let ratings = brews.compactMap(\.rating)
        return BrewStats(
            totalBrews: brews.count,
            totalCoffeeG: brews.reduce(0) { $0 + $1.doseG },
            avgRating: ratings.isEmpty ? nil : Decimal(ratings.reduce(0, +)) / Decimal(ratings.count)
        )
    }
}

extension PreviewBackend: SocialRepository {
    public func homeFeed(after cursor: FeedCursor?, limit: Int) async throws -> [Post] { cursor == nil ? posts : [] }
    public func exploreFeed(offset: Int, limit: Int, kind: PostKind?) async throws -> [Post] {
        offset == 0 ? posts.filter { kind == nil || $0.kind == kind } : []
    }
    public func posts(authorID: UUID, after cursor: FeedCursor?, limit: Int) async throws -> [Post] {
        cursor == nil ? posts.filter { $0.authorID == authorID } : []
    }
    public func savedPosts() async throws -> [Post] { posts.filter(\.savedByMe) }
    public func publish(_ request: PublishRequest) async throws -> Post {
        let post = Post(
            authorID: me.id, kind: request.kind, caption: request.caption, visibility: request.visibility,
            commentsEnabled: request.commentsEnabled, author: me,
            recipe: recipes.first { $0.id == request.contentID },
            brew: brews.first { $0.id == request.contentID },
            bean: beans.first { $0.id == request.contentID }
        )
        posts.insert(post, at: 0)
        return post
    }
    public func deletePost(id: UUID) async throws { posts.removeAll { $0.id == id } }
    public func setLiked(_ liked: Bool, postID: UUID) async throws {}
    public func setSaved(_ saved: Bool, postID: UUID) async throws {}
    public func comments(postID: UUID) async throws -> [Comment] { comments.filter { $0.postID == postID } }
    public func addComment(postID: UUID, body: String, parentID: UUID?) async throws -> Comment {
        let comment = Comment(postID: postID, authorID: me.id, parentID: parentID, body: body, author: me)
        comments.append(comment)
        return comment
    }
    public func deleteComment(id: UUID) async throws { comments.removeAll { $0.id == id } }
    public func mediaURL(for media: PostMedia) async throws -> URL { URL(string: "about:blank")! }
}

extension PreviewBackend: RelationshipRepository {
    public func follow(userID: UUID) async throws -> FollowStatus { .accepted }
    public func unfollow(userID: UUID) async throws {}
    public func pendingRequests() async throws -> [Profile] { [] }
    public func respond(toRequestFrom userID: UUID, accept: Bool) async throws {}
    public func followers(of userID: UUID) async throws -> [Profile] { [] }
    public func following(of userID: UUID) async throws -> [Profile] { [] }
    public func block(userID: UUID) async throws {}
    public func unblock(userID: UUID) async throws {}
}

extension PreviewBackend: NotificationRepository {
    public func notifications(limit: Int) async throws -> [AppNotification] { [] }
    public func unreadCount() async throws -> Int { 0 }
    public func markAllAsRead() async throws {}
    public func registerPushToken(_ token: String) async throws {}
    public nonisolated func liveNotifications() -> AsyncStream<Void> { AsyncStream { _ in } }
}
