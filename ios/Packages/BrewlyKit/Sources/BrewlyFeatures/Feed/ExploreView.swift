import BrewlyDomain
import SwiftUI

/// Descubrir: búsqueda de baristas y publicaciones públicas populares.
struct ExploreView: View {
    @Environment(\.dependencies) private var dependencies

    @State private var query = ""
    @State private var results: [Profile] = []
    @State private var kind: PostKind?
    @State private var model: FeedViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if !query.isEmpty {
                    List(results) { profile in
                        NavigationLink(value: profile) {
                            ProfileRow(profile: profile)
                        }
                    }
                    .listStyle(.plain)
                } else if let model {
                    PostList(model: model, emptyTitle: "Nada por aquí todavía",
                             emptyMessage: "Las publicaciones públicas más recientes aparecerán aquí.")
                }
            }
            .navigationTitle("Explorar")
            .searchable(text: $query, prompt: "Buscar baristas")
            .task(id: query) {
                // Debounce sencillo: la tarea se cancela si el texto cambia.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = (try? await dependencies.profiles.search(query)) ?? []
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Tipo", selection: $kind) {
                            Text("Todo").tag(PostKind?.none)
                            Text("Recetas").tag(PostKind?.some(.recipe))
                            Text("Preparaciones").tag(PostKind?.some(.brew))
                            Text("Cafés").tag(PostKind?.some(.bean))
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .brewlyDestinations()
        }
        .task(id: kind) {
            let model = FeedViewModel(source: .explore(kind), social: dependencies.social)
            self.model = model
            await model.refresh()
        }
    }
}

struct ProfileRow: View {
    @Environment(\.dependencies) private var dependencies
    let profile: Profile

    var body: some View {
        HStack {
            AvatarView(url: profile.avatarPath.flatMap { dependencies.profiles.publicAvatarURL(path: $0) })
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(profile.nameToDisplay).font(.subheadline.bold())
                    if profile.isPrivate {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text("@\(profile.username) · \(profile.role.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
