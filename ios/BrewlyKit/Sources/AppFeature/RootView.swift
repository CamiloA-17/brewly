import AuthFeature
import BeansFeature
import BrewlyDesignSystem
import BrewlyDomain
import FeedFeature
import MethodsFeature
import ProfileFeature
import RecipesFeature
import SwiftUI

/// Entry point of the UI: sign-in flow or the main tabs.
public struct RootView: View {
    private let container: AppContainer
    @State private var model: AppViewModel

    public init(container: AppContainer) {
        self.container = container
        _model = State(initialValue: AppViewModel(container: container))
    }

    public var body: some View {
        Group {
            switch model.phase {
            case .launching:
                ProgressView()
            case .signedOut:
                AuthView(dependencies: container.authDependencies) { user in
                    model.didSignIn(user)
                }
            case let .signedIn(user):
                MainTabView(container: container, user: user) {
                    model.didSignOut()
                }
                .id(user.id)
            }
        }
        .tint(Color.brewlyAccent)
        .task { await model.start() }
    }
}

struct MainTabView: View {
    let container: AppContainer
    let user: UserProfile
    let onSignedOut: @MainActor () -> Void

    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label {
                        Text("Home", bundle: .module)
                    } icon: {
                        Image(systemName: "house")
                    }
                }
            RecipesRootView(dependencies: container.recipesDependencies(currentUserID: user.id))
                .tabItem {
                    Label {
                        Text("Recipes", bundle: .module)
                    } icon: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                }
            BeansRootView(dependencies: container.beansDependencies)
                .tabItem {
                    Label {
                        Text("Beans", bundle: .module)
                    } icon: {
                        Image(systemName: "leaf")
                    }
                }
            MethodsView(dependencies: container.methodsDependencies)
                .tabItem {
                    Label {
                        Text("Methods", bundle: .module)
                    } icon: {
                        Image(systemName: "cup.and.saucer")
                    }
                }
            ProfileView(user: user, dependencies: container.profileDependencies, onSignedOut: onSignedOut)
                .tabItem {
                    Label {
                        Text("Profile", bundle: .module)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }
        }
    }
}
