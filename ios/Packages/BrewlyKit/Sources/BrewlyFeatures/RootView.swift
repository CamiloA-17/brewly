import BrewlyDomain
import SwiftUI

/// Vista raíz: decide entre autenticación y la app principal.
public struct RootView: View {
    @State private var session: SessionStore

    public init(dependencies: AppDependencies) {
        _session = State(initialValue: SessionStore(dependencies: dependencies))
    }

    public var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView()
            case .signedOut:
                AuthView()
            case .signedIn:
                MainTabView()
            }
        }
        .environment(session)
        .environment(\.dependencies, session.dependencies)
        .tint(BrewlyTheme.accent)
        .task { session.start() }
    }
}

struct MainTabView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Inicio", systemImage: "house") }
            ExploreView()
                .tabItem { Label("Explorar", systemImage: "magnifyingglass") }
            LibraryView()
                .tabItem { Label("Mi barra", systemImage: "cup.and.saucer") }
            NotificationsView()
                .tabItem { Label("Actividad", systemImage: "bell") }
            NavigationStack {
                if let id = session.currentUserID {
                    ProfileView(userID: id)
                        .brewlyDestinations()
                }
            }
            .tabItem { Label("Perfil", systemImage: "person") }
        }
    }
}

#Preview {
    RootView(dependencies: PreviewBackend.dependencies)
}
