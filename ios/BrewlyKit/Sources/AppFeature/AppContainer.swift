import AuthFeature
import BeansFeature
import BrewlyData
import BrewlyDesignSystem
import BrewlyDomain
import BrewlyNetworking
import FeedFeature
import Foundation
import JournalFeature
import MethodsFeature
import NotificationsFeature
import PeopleFeature
import ProfileFeature
import RecipesFeature
import SwiftUI

/// Composition root: builds the concrete data layer and hands each feature
/// only the domain abstractions it needs.
@MainActor
public final class AppContainer {
    let session: SessionManager
    let auth: any AuthRepository
    let profile: any ProfileRepository
    let catalog: any CatalogRepository
    let userMethods: any UserMethodsRepository
    let beans: any BeanRepository
    let recipes: any RecipeRepository
    let saves: any RecipeSavesRepository
    let people: any PeopleRepository
    let posts: any PostRepository
    let imageLoader: any ImageLoader
    let notifications: any NotificationRepository
    let equipment: any EquipmentRepository
    let brews: any BrewLogRepository

    public init(apiBaseURL: URL, tokenStore: any TokenStore = KeychainTokenStore()) {
        let publicClient = APIClient(baseURL: apiBaseURL)
        let session = SessionManager(client: publicClient, store: tokenStore)
        let client = APIClient(baseURL: apiBaseURL, tokenProvider: session)

        self.session = session
        auth = APIAuthRepository(publicClient: publicClient, session: session)
        profile = APIProfileRepository(client: client, session: session)
        catalog = APICatalogRepository(client: client)
        userMethods = APIUserMethodsRepository(client: client)
        beans = APIBeanRepository(client: client)
        let recipeRepository = APIRecipeRepository(client: client)
        recipes = recipeRepository
        saves = recipeRepository
        people = APIPeopleRepository(client: client)
        posts = APIPostRepository(client: client)
        imageLoader = APIImageLoader(client: client)
        notifications = APINotificationRepository(client: client)
        equipment = APIEquipmentRepository(client: client)
        brews = APIBrewLogRepository(client: client)
    }

    func feedDependencies(currentUserID: UUID) -> FeedDependencies {
        FeedDependencies(posts: posts, notifications: notifications, recipes: recipes, beans: beans, catalog: catalog, currentUserID: currentUserID)
    }

    var authDependencies: AuthDependencies {
        AuthDependencies(
            signIn: SignInUseCase(auth: auth),
            signUp: SignUpUseCase(auth: auth),
            completeOnboarding: CompleteOnboardingUseCase(profile: profile)
        )
    }

    var beansDependencies: BeansDependencies {
        BeansDependencies(beans: beans, catalog: catalog, saveBean: SaveBeanUseCase(beans: beans))
    }

    func recipesDependencies(currentUserID: UUID) -> RecipesDependencies {
        RecipesDependencies(
            recipes: recipes,
            saves: saves,
            beans: beans,
            catalog: catalog,
            userMethods: userMethods,
            equipment: equipment,
            saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: currentUserID
        )
    }

    func journalDependencies(currentUserID: UUID) -> JournalDependencies {
        JournalDependencies(
            brews: brews,
            beans: beans,
            recipes: recipes,
            catalog: catalog,
            equipment: equipment,
            saveBrew: SaveBrewLogUseCase(brews: brews),
            currentUserID: currentUserID
        )
    }

    var methodsDependencies: MethodsDependencies {
        MethodsDependencies(catalog: catalog, userMethods: userMethods)
    }

    var profileDependencies: ProfileDependencies {
        ProfileDependencies(profile: profile, auth: auth, people: people, equipment: equipment, catalog: catalog)
    }

    var peopleDependencies: PeopleDependencies {
        PeopleDependencies(people: people, posts: posts, catalog: catalog, equipment: equipment)
    }

    /// The screen each `AppRoute` opens, shared by every tab.
    func routeDestinations(currentUserID: UUID) -> RouteDestinations {
        RouteDestinations { [self] route in
            switch route {
            case let .member(id):
                AnyView(MemberProfileView(memberID: id, dependencies: peopleDependencies))
            case let .recipe(id):
                AnyView(RecipeDetailView(recipeID: id, dependencies: recipesDependencies(currentUserID: currentUserID)))
            case .notifications:
                AnyView(NotificationsView(dependencies: NotificationsDependencies(notifications: notifications)))
            case let .post(id):
                AnyView(PostDetailView(postID: id, dependencies: feedDependencies(currentUserID: currentUserID)))
            case .memberSearch:
                AnyView(MemberSearchView(dependencies: peopleDependencies))
            case let .followers(memberID):
                AnyView(FollowListView(memberID: memberID, kind: .followers, dependencies: peopleDependencies))
            case let .following(memberID):
                AnyView(FollowListView(memberID: memberID, kind: .following, dependencies: peopleDependencies))
            case let .brew(id):
                AnyView(BrewLogDetailView(brewID: id, dependencies: journalDependencies(currentUserID: currentUserID)))
            case let .newBrew(recipeID):
                AnyView(BrewLogFormView(
                    brewLog: nil, recipeID: recipeID, dependencies: journalDependencies(currentUserID: currentUserID)
                ))
            case .methods:
                AnyView(MethodsView(dependencies: methodsDependencies))
            }
        }
    }
}
