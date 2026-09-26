import BrewlyDomain
import SwiftUI

/// A member's picture, or their initials on a crema circle.
public struct AvatarView: View {
    private let name: String
    private let url: URL?
    private let size: CGFloat

    public init(name: String, url: URL? = nil, size: CGFloat = 40) {
        self.name = name
        self.url = url
        self.size = size
    }

    public var body: some View {
        Group {
            if let url {
                RemoteImage(url: url)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.brewlyEspresso)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brewlyCrema)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// A member in a list: avatar, display name and username.
public struct MemberRow: View {
    private let member: UserSummary

    public init(member: UserSummary) {
        self.member = member
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            AvatarView(name: member.displayName, url: member.avatarURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).font(.headline)
                Text(verbatim: "@\(member.username)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A recipe in a list: title, rating, method, bean and the main parameters.
public struct RecipeSummaryRow: View {
    private let recipe: RecipeSummary
    private let catalog: Catalog
    private let showsAuthor: Bool

    public init(recipe: RecipeSummary, catalog: Catalog, showsAuthor: Bool) {
        self.recipe = recipe
        self.catalog = catalog
        self.showsAuthor = showsAuthor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title).font(.headline)
                Spacer()
                if let rating = recipe.averageRating {
                    AverageRatingView(rating: rating, count: recipe.brewCount).font(.caption2)
                }
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            RecipeParametersRow(
                doseG: recipe.doseG,
                ratio: recipe.ratio,
                grindSize: recipe.grindSize,
                waterTempC: recipe.waterTempC,
                totalTimeS: recipe.totalTimeS
            )
        }
        .padding(.vertical, Spacing.xs)
    }

    private var subtitle: String {
        let method = catalog.brewMethod(recipe.methodSlug)?.localizedName ?? recipe.methodSlug
        var parts = [method, recipe.beanName]
        if showsAuthor { parts.append("@" + recipe.author.username) }
        return parts.joined(separator: " · ")
    }
}

/// List rows linking to a member's followers and the people they follow.
/// Titles are passed in so each feature localizes them.
public struct FollowCountLinks: View {
    private let memberID: UUID
    private let followers: Int
    private let following: Int
    private let followersTitle: Text
    private let followingTitle: Text

    public init(memberID: UUID, followers: Int, following: Int, followersTitle: Text, followingTitle: Text) {
        self.memberID = memberID
        self.followers = followers
        self.following = following
        self.followersTitle = followersTitle
        self.followingTitle = followingTitle
    }

    public var body: some View {
        NavigationLink(value: AppRoute.followers(of: memberID)) {
            LabeledContent {
                Text(followers, format: .number)
            } label: {
                followersTitle
            }
        }
        NavigationLink(value: AppRoute.following(of: memberID)) {
            LabeledContent {
                Text(following, format: .number)
            } label: {
                followingTitle
            }
        }
    }
}
