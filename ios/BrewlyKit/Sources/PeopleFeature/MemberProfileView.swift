import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Another member's profile: who they are, their follow counts and the recipes you can see.
public struct MemberProfileView: View {
    @State private var model: MemberProfileViewModel

    public init(memberID: UUID, dependencies: PeopleDependencies) {
        _model = State(initialValue: MemberProfileViewModel(memberID: memberID, dependencies: dependencies))
    }

    public var body: some View {
        AsyncContentView(model.state, retry: model.load) { profile in
            List {
                Section {
                    header(profile)
                    FollowCountLinks(
                        memberID: profile.id,
                        followers: profile.followerCount,
                        following: profile.followingCount,
                        followersTitle: Text("Followers", bundle: .module),
                        followingTitle: Text("Following", bundle: .module)
                    )
                    if !profile.isMe {
                        followButton(profile)
                    }
                    FieldErrorText(model.errorMessage)
                }
                recipesSection(profile)
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(Text(verbatim: model.state.value.map { "@\($0.username)" } ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func header(_ profile: MemberProfile) -> some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            AvatarView(name: profile.displayName, size: 64)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(profile.displayName).font(.title3.bold())
                HStack(spacing: Spacing.s) {
                    Text(verbatim: "@\(profile.username)").foregroundStyle(.secondary)
                    if profile.followsYou {
                        Text("Follows you", bundle: .module)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, 2)
                            .background(Color.brewlyCrema, in: Capsule())
                            .foregroundStyle(Color.brewlyEspresso)
                    }
                }
                if let bio = profile.bio {
                    Text(bio).padding(.top, Spacing.xs)
                }
                if let location = profile.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func followButton(_ profile: MemberProfile) -> some View {
        let button = Button {
            Task { await model.toggleFollow() }
        } label: {
            Group {
                if profile.isFollowing {
                    Text("Following", bundle: .module)
                } else if profile.followsYou {
                    Text("Follow back", bundle: .module)
                } else {
                    Text("Follow", bundle: .module)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(model.isUpdatingFollow)
        if profile.isFollowing {
            button.buttonStyle(.bordered)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func recipesSection(_ profile: MemberProfile) -> some View {
        Section {
            switch model.recipes.state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .failed:
                Text("Couldn't load the recipes.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(recipes) where recipes.isEmpty:
                Text("No recipes to show yet.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(recipes):
                ForEach(recipes) { recipe in
                    NavigationLink(value: AppRoute.recipe(recipe.id)) {
                        RecipeSummaryRow(recipe: recipe, catalog: model.catalog, showsAuthor: false)
                    }
                }
                if model.recipes.canLoadMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task { await model.recipes.loadMore() }
                }
            }
        } header: {
            HStack {
                Text("Recipes", bundle: .module)
                Spacer()
                Text(profile.recipeCount, format: .number)
            }
        }
    }
}
