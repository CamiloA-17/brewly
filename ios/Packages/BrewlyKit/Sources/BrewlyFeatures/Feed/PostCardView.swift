import BrewlyDomain
import SwiftUI

struct PostCardView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    let post: Post
    var onLike: () -> Void = {}
    var onSave: () -> Void = {}
    var onDelete: () -> Void = {}
    var showsCommentLink = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !post.media.isEmpty {
                PostMediaCarousel(media: post.media)
            }

            content

            if let caption = post.caption, !caption.isEmpty {
                Text(caption).font(.body)
            }

            actions
        }
        .brewlyCard()
    }

    private var header: some View {
        HStack {
            if let author = post.author {
                NavigationLink(value: author) {
                    HStack {
                        AvatarView(url: author.avatarPath.flatMap { dependencies.profiles.publicAvatarURL(path: $0) })
                        VStack(alignment: .leading) {
                            Text(author.nameToDisplay).font(.subheadline.bold())
                            Text("@\(author.username) · \(post.createdAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if post.authorID == session.currentUserID {
                Menu {
                    Button("Eliminar publicación", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis").padding(8)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch post.kind {
        case .recipe:
            if let recipe = post.recipe {
                NavigationLink(value: recipe) {
                    RecipeSummaryView(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        case .brew:
            if let brew = post.brew {
                BrewSummaryView(brew: brew)
            }
        case .bean:
            if let bean = post.bean {
                BeanSummaryView(bean: bean)
            }
        case .note:
            EmptyView()
        }
    }

    private var actions: some View {
        HStack(spacing: 20) {
            Button(action: onLike) {
                Label("\(post.likeCount)", systemImage: post.likedByMe ? "heart.fill" : "heart")
                    .foregroundStyle(post.likedByMe ? .red : .primary)
            }
            if showsCommentLink {
                NavigationLink(value: post) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                }
            } else {
                Label("\(post.commentCount)", systemImage: "bubble.right")
            }
            Spacer()
            Button(action: onSave) {
                Image(systemName: post.savedByMe ? "bookmark.fill" : "bookmark")
            }
        }
        .buttonStyle(.borderless)
        .font(.subheadline)
        .labelStyle(.titleAndIcon)
    }
}

struct PostMediaCarousel: View {
    @Environment(\.dependencies) private var dependencies
    let media: [PostMedia]
    @State private var urls: [UUID: URL] = [:]

    var body: some View {
        TabView {
            ForEach(media) { item in
                AsyncImage(url: urls[item.id]) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(BrewlyTheme.latte)
                }
                .clipped()
            }
        }
        .tabViewStyle(.page)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: BrewlyTheme.cornerRadius))
        .task {
            for item in media where urls[item.id] == nil {
                urls[item.id] = try? await dependencies.social.mediaURL(for: item)
            }
        }
    }
}

struct RecipeSummaryView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(recipe.method?.name ?? "Receta", systemImage: recipe.method?.icon ?? "list.bullet.rectangle")
                .font(.caption.bold())
                .foregroundStyle(BrewlyTheme.crema)
            Text(recipe.title).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    MetricPill(systemImage: "scalemass", value: Format.grams(recipe.doseG))
                    if recipe.waterG != nil {
                        MetricPill(systemImage: "drop", value: Format.grams(recipe.waterG))
                        MetricPill(systemImage: "divide", value: Format.ratio(recipe.ratio ?? recipe.computedRatio))
                    }
                    if let yield = recipe.yieldG {
                        MetricPill(systemImage: "cup.and.saucer", value: Format.grams(yield))
                    }
                    MetricPill(systemImage: "thermometer.medium", value: Format.temperature(recipe.waterTempC))
                    MetricPill(systemImage: "timer", value: Format.duration(recipe.totalTimeS))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BrewSummaryView: View {
    let brew: Brew

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Preparación", systemImage: "mug").font(.caption.bold()).foregroundStyle(BrewlyTheme.crema)
                Spacer()
                if let rating = brew.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            HStack {
                MetricPill(systemImage: "scalemass", value: Format.grams(brew.doseG))
                MetricPill(systemImage: "drop", value: Format.grams(brew.waterG ?? brew.yieldG))
                MetricPill(systemImage: "timer", value: Format.duration(brew.totalTimeS))
            }
            if !brew.tastingNotes.isEmpty {
                Text(brew.tastingNotes.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BeanSummaryView: View {
    let bean: CoffeeBean

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Café", systemImage: "leaf").font(.caption.bold()).foregroundStyle(BrewlyTheme.crema)
            Text(bean.name).font(.headline)
            if let roaster = bean.roaster {
                Text(roaster).font(.subheadline).foregroundStyle(.secondary)
            }
            Text([bean.originSummary, bean.process?.title, bean.roastLevel?.title]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.footnote)
            if !bean.tastingNotes.isEmpty {
                Text(bean.tastingNotes.joined(separator: ", ")).font(.footnote).italic()
            }
        }
    }
}
