import BrewlyDomain
import SwiftUI

struct ProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    let userID: UUID

    @State private var profile: Profile?
    @State private var posts: FeedViewModel?
    @State private var isEditing = false
    @State private var isShowingRequests = false
    @State private var errorMessage: String?

    private var isMe: Bool { userID == session.currentUserID }

    /// Una cuenta privada solo muestra sus posts a seguidores aceptados.
    private var canSeePosts: Bool {
        guard let profile else { return false }
        return isMe || !profile.isPrivate || profile.viewerFollowStatus == .accepted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let profile {
                    header(profile)
                }
                if canSeePosts, let posts {
                    LazyVStack(spacing: 16) {
                        ForEach(posts.posts) { post in
                            PostCardView(
                                post: post,
                                onLike: { Task { await posts.toggleLike(post) } },
                                onSave: { Task { await posts.toggleSave(post) } },
                                onDelete: { Task { await posts.delete(post) } }
                            )
                            .task { await posts.loadMoreIfNeeded(current: post) }
                        }
                    }
                } else if profile != nil {
                    ContentUnavailableView(
                        "Esta cuenta es privada",
                        systemImage: "lock",
                        description: Text("Síguela para ver sus recetas y preparaciones.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle(profile.map { "@\($0.username)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMe {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Editar perfil", systemImage: "pencil") { isEditing = true }
                        Button("Solicitudes de seguimiento", systemImage: "person.badge.clock") {
                            isShowingRequests = true
                        }
                        Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            Task { await session.signOut() }
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            } else if profile != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Bloquear", systemImage: "hand.raised", role: .destructive) {
                            Task { await block() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isShowingRequests) {
            FollowRequestsView()
        }
        .sheet(isPresented: $isEditing) {
            if let profile {
                EditProfileView(profile: profile) { updated in
                    self.profile = updated
                    session.updateProfile(updated)
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func header(_ profile: Profile) -> some View {
        VStack(spacing: 12) {
            AvatarView(url: profile.avatarPath.flatMap { dependencies.profiles.publicAvatarURL(path: $0) }, size: 88)
            VStack(spacing: 4) {
                Text(profile.nameToDisplay).font(.title3.bold())
                Text(profile.role.title).font(.subheadline).foregroundStyle(BrewlyTheme.crema)
                if let bio = profile.bio {
                    Text(bio).font(.subheadline).multilineTextAlignment(.center)
                }
                if let location = profile.location {
                    Label(location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 32) {
                stat(profile.postsCount, "Publicaciones")
                NavigationLink {
                    ProfileListView(title: "Seguidores") { try await dependencies.relationships.followers(of: userID) }
                } label: { stat(profile.followersCount, "Seguidores") }
                NavigationLink {
                    ProfileListView(title: "Siguiendo") { try await dependencies.relationships.following(of: userID) }
                } label: { stat(profile.followingCount, "Siguiendo") }
            }
            .buttonStyle(.plain)
            .disabled(!canSeePosts)

            if !isMe {
                followButton(profile)
            }
        }
    }

    private func stat(_ value: Int, _ title: String) -> some View {
        VStack {
            Text("\(value)").font(.headline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func followButton(_ profile: Profile) -> some View {
        switch profile.viewerFollowStatus ?? .notFollowing {
        case .accepted:
            Button("Siguiendo") { Task { await unfollow() } }
                .buttonStyle(.bordered)
        case .pending:
            Button("Solicitud enviada") { Task { await unfollow() } }
                .buttonStyle(.bordered)
        case .notFollowing:
            Button(profile.isPrivate ? "Solicitar seguir" : "Seguir") { Task { await follow() } }
                .buttonStyle(.borderedProminent)
        case .own:
            EmptyView()
        }
    }

    private func load() async {
        do {
            profile = try await dependencies.profiles.profile(id: userID)
            if canSeePosts {
                let model = posts ?? FeedViewModel(source: .author(userID), social: dependencies.social)
                posts = model
                await model.refresh()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func follow() async {
        do {
            let status = try await dependencies.relationships.follow(userID: userID)
            profile?.viewerFollowStatus = status
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unfollow() async {
        do {
            try await dependencies.relationships.unfollow(userID: userID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func block() async {
        do {
            try await dependencies.relationships.block(userID: userID)
            profile = nil
            posts = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Lista genérica de perfiles (seguidores / siguiendo).
struct ProfileListView: View {
    let title: String
    let load: () async throws -> [Profile]
    @State private var profiles: [Profile] = []

    var body: some View {
        List(profiles) { profile in
            NavigationLink(value: profile) { ProfileRow(profile: profile) }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .task { profiles = (try? await load()) ?? [] }
    }
}

struct FollowRequestsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var requests: [Profile] = []

    var body: some View {
        List(requests) { profile in
            HStack {
                ProfileRow(profile: profile)
                Spacer()
                Button("Aceptar") { Task { await respond(profile, accept: true) } }
                    .buttonStyle(.borderedProminent)
                Button("Rechazar") { Task { await respond(profile, accept: false) } }
                    .buttonStyle(.bordered)
            }
        }
        .overlay {
            if requests.isEmpty {
                ContentUnavailableView("Sin solicitudes", systemImage: "person.badge.clock")
            }
        }
        .navigationTitle("Solicitudes")
        .task { requests = (try? await dependencies.relationships.pendingRequests()) ?? [] }
    }

    private func respond(_ profile: Profile, accept: Bool) async {
        try? await dependencies.relationships.respond(toRequestFrom: profile.id, accept: accept)
        requests.removeAll { $0.id == profile.id }
    }
}
