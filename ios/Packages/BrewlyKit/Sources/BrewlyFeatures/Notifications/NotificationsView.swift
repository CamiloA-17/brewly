import BrewlyDomain
import SwiftUI

struct NotificationsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var items: [AppNotification] = []

    var body: some View {
        NavigationStack {
            List(items) { item in
                HStack(alignment: .top) {
                    AvatarView(url: item.actor?.avatarPath.flatMap { dependencies.profiles.publicAvatarURL(path: $0) })
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.message).font(.subheadline)
                        Text(item.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !item.isRead {
                        Circle().fill(BrewlyTheme.crema).frame(width: 8, height: 8)
                    }
                }
                .background {
                    if let actor = item.actor {
                        NavigationLink(value: actor) { EmptyView() }.opacity(0)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("Sin actividad", systemImage: "bell",
                                           description: Text("Aquí verás likes, comentarios y nuevos seguidores."))
                }
            }
            .navigationTitle("Actividad")
            .refreshable { await load() }
            .brewlyDestinations()
        }
        .task {
            await load()
            // Recarga en tiempo real cuando llega una notificación nueva.
            for await _ in dependencies.notifications.liveNotifications() {
                await load()
            }
        }
    }

    private func load() async {
        items = (try? await dependencies.notifications.notifications(limit: 50)) ?? []
        if items.contains(where: { !$0.isRead }) {
            try? await dependencies.notifications.markAllAsRead()
        }
    }
}
