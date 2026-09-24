import BrewlyDomain
import SwiftUI

struct FeedView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: FeedViewModel?
    @State private var isPublishing = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    PostList(model: model, emptyTitle: "Tu feed está vacío",
                             emptyMessage: "Sigue a otros baristas o publica tu primera receta.")
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Brewly")
            .brewlyDestinations()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPublishing = true
                    } label: {
                        Image(systemName: "plus.square")
                    }
                    .accessibilityLabel("Publicar")
                }
            }
            .sheet(isPresented: $isPublishing) {
                PublishView { post in model?.insert(post) }
            }
        }
        .task {
            if model == nil {
                let model = FeedViewModel(source: .home, social: dependencies.social)
                self.model = model
                await model.refresh()
            }
        }
    }
}

/// Lista de posts reutilizada por el feed, explorar y el perfil.
struct PostList: View {
    @Bindable var model: FeedViewModel
    var emptyTitle: String
    var emptyMessage: String

    var body: some View {
        // ScrollView + LazyVStack (en lugar de List) para que cada tarjeta pueda
        // contener varios enlaces de navegación independientes.
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(model.posts) { post in
                    PostCardView(
                        post: post,
                        onLike: { Task { await model.toggleLike(post) } },
                        onSave: { Task { await model.toggleSave(post) } },
                        onDelete: { Task { await model.delete(post) } }
                    )
                    .task { await model.loadMoreIfNeeded(current: post) }
                }
                if model.isLoading && !model.posts.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .overlay {
            if model.posts.isEmpty && !model.isLoading {
                ContentUnavailableView(emptyTitle, systemImage: "cup.and.saucer", description: Text(emptyMessage))
            }
        }
        .refreshable { await model.refresh() }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

extension View {
    /// Destinos de navegación comunes (posts, perfiles, recetas). Se registran
    /// una sola vez en la raíz de cada `NavigationStack`.
    func brewlyDestinations() -> some View {
        navigationDestination(for: Post.self) { PostDetailView(post: $0) }
            .navigationDestination(for: Profile.self) { ProfileView(userID: $0.id) }
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipeID: $0.id, preview: $0) }
    }
}
