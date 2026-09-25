import BrewlyDomain
import SwiftUI
import UIKit

/// A post in a feed: author, text, photos, what it shares, likes and comments.
///
/// Use it inside a `ScrollView`, not a `List`, so each link and button reacts on its own.
public struct PostCard: View {
    private let post: Post
    private let catalog: Catalog
    private let onLike: @MainActor () -> Void

    public init(post: Post, catalog: Catalog, onLike: @escaping @MainActor () -> Void) {
        self.post = post
        self.catalog = catalog
        self.onLike = onLike
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            header
            if let body = post.body {
                NavigationLink(value: AppRoute.post(post.id)) {
                    Text(body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            photos
            attachment
            actions
        }
        .padding(Spacing.l)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            NavigationLink(value: AppRoute.member(post.author.id)) {
                HStack(spacing: Spacing.s) {
                    AvatarView(name: post.author.displayName, url: post.author.avatarURL, size: 36)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(post.author.displayName).font(.subheadline.bold())
                        Text(verbatim: "@\(post.author.username)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if post.visibility != .public {
                Image(systemName: post.visibility == .followers ? "person.2" : "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(post.visibility.localizedName)
            }
            Text(post.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var photos: some View {
        if post.media.count == 1, let photo = post.media.first {
            PhotoView(media: photo)
        } else if post.media.count > 1, let first = post.media.first {
            TabView {
                ForEach(post.media) { photo in
                    RemoteImage(url: photo.url)
                        .clipped()
                }
            }
            .tabViewStyle(.page)
            .aspectRatio(CGFloat(min(max(first.aspectRatio, 0.8), 1.91)), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var attachment: some View {
        if let recipe = post.recipe {
            NavigationLink(value: AppRoute.recipe(recipe.id)) {
                RecipeSummaryRow(recipe: recipe, catalog: catalog, showsAuthor: false)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brewlyCrema.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else if let bean = post.bean {
            BeanAttachmentView(bean: bean, catalog: catalog)
        } else if post.kind != .text {
            Label {
                post.kind == .recipe
                    ? Text("This recipe isn't available.", bundle: .module)
                    : Text("This bean isn't available.", bundle: .module)
            } icon: {
                Image(systemName: "eye.slash")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack(spacing: Spacing.xl) {
            Button(action: onLike) {
                Label {
                    Text(post.likeCount, format: .number)
                } icon: {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? Color.brewlyAccent : .secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(post.isLiked ? Text("Unlike", bundle: .module) : Text("Like", bundle: .module))
            NavigationLink(value: AppRoute.post(post.id)) {
                Label {
                    Text(post.commentCount, format: .number)
                } icon: {
                    Image(systemName: "bubble.right").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Comments", bundle: .module))
            Spacer()
        }
        .font(.subheadline)
    }
}

/// A shared bean: name, roaster and origin.
struct BeanAttachmentView: View {
    let bean: BeanSummary
    let catalog: Catalog

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "leaf")
                .font(.title3)
                .foregroundStyle(Color.brewlyAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(bean.name).font(.headline)
                let details = [bean.roaster, catalog.country(bean.countryCode)?.localizedName, bean.farm].compactMap { $0 }
                if !details.isEmpty {
                    Text(details.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .background(Color.brewlyCrema.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A compact post in a list: first photo or an icon, the text and the counts.
public struct PostSummaryRow: View {
    private let post: Post

    public init(post: Post) {
        self.post = post
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            Group {
                if let photo = post.media.first {
                    RemoteImage(url: photo.url)
                } else {
                    Image(systemName: post.kind == .bean ? "leaf" : post.kind == .recipe ? "list.bullet.clipboard" : "text.bubble")
                        .foregroundStyle(Color.brewlyAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.brewlyCrema)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).lineLimit(2)
                HStack(spacing: Spacing.m) {
                    Label { Text(post.likeCount, format: .number) } icon: { Image(systemName: "heart") }
                    Label { Text(post.commentCount, format: .number) } icon: { Image(systemName: "bubble.right") }
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var title: String {
        if let body = post.body { return body }
        if let recipe = post.recipe { return recipe.title }
        if let bean = post.bean { return bean.name }
        return String(localized: "Photo", bundle: .module)
    }
}
