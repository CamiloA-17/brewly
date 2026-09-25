import AuthFeature
import BeansFeature
import BrewlyData
import BrewlyDomain
import BrewlyNetworking
import Foundation
import MethodsFeature
import ProfileFeature
import RecipesFeature

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
        recipes = APIRecipeRepository(client: client)
    }

    var authDependencies: AuthDependencies {
        AuthDependencies(signIn: SignInUseCase(auth: auth), signUp: SignUpUseCase(auth: auth))
    }

    var beansDependencies: BeansDependencies {
        BeansDependencies(beans: beans, catalog: catalog, saveBean: SaveBeanUseCase(beans: beans))
    }

    func recipesDependencies(currentUserID: UUID) -> RecipesDependencies {
        RecipesDependencies(
            recipes: recipes,
            beans: beans,
            catalog: catalog,
            userMethods: userMethods,
            saveRecipe: SaveRecipeUseCase(recipes: recipes),
            currentUserID: currentUserID
        )
    }

    var methodsDependencies: MethodsDependencies {
        MethodsDependencies(catalog: catalog, userMethods: userMethods)
    }

    var profileDependencies: ProfileDependencies {
        ProfileDependencies(profile: profile, auth: auth)
    }
}
