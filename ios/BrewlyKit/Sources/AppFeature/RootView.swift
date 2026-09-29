import AuthFeature
import BeansFeature
import BrewlyDesignSystem
import BrewlyDomain
import FeedFeature
import JournalFeature
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
            case let .onboarding(user):
                OnboardingView(user: user, dependencies: container.authDependencies) { completed in
                    model.didSignIn(completed)
                } onSignOut: {
                    Task { await model.signOut() }
                }
            case let .signedIn(user):
                MainTabView(container: container, user: user) {
                    model.didSignOut()
                }
                .id(user.id)
            }
        }
        .tint(Color.brewlyAccent)
        .brewlyAppearance()
        .task { await model.start() }
    }
}

struct MainTabView: View {
    let container: AppContainer
    let user: UserProfile
    let onSignedOut: @MainActor () -> Void

    var body: some View {
        TabView {
            FeedView(dependencies: container.feedDependencies(currentUserID: user.id))
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
            JournalView(dependencies: container.journalDependencies(currentUserID: user.id))
                .tabItem {
                    Label {
                        Text("Journal", bundle: .module)
                    } icon: {
                        Image(systemName: "book.closed")
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
            ProfileView(user: user, dependencies: container.profileDependencies, onSignedOut: onSignedOut)
                .tabItem {
                    Label {
                        Text("Profile", bundle: .module)
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }
        }
        .environment(\.routeDestinations, container.routeDestinations(currentUserID: user.id))
        .environment(\.imageLoader, container.imageLoader)
    }
}
