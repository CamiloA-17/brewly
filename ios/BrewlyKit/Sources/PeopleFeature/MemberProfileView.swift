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
                Section {
                    Picker(selection: $model.tab) {
                        Text("Recipes", bundle: .module).tag(MemberProfileViewModel.Tab.recipes)
                        Text("Posts", bundle: .module).tag(MemberProfileViewModel.Tab.posts)
                        Text("Equipment", bundle: .module).tag(MemberProfileViewModel.Tab.equipment)
                    } label: {
                        Text("Show", bundle: .module)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                switch model.tab {
                case .recipes: recipesSection(profile)
                case .posts: postsSection
                case .equipment: equipmentSection
                }
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(Text(verbatim: model.state.value.map { "@\($0.username)" } ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: model.tab) {
            Task { await model.loadTab() }
        }
    }

    private func header(_ profile: MemberProfile) -> some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            AvatarView(name: profile.displayName, url: profile.avatarURL, size: 64)
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
                if let place = memberPlace(city: profile.city, countryCode: profile.countryCode) {
                    Label(place, systemImage: "mappin.and.ellipse")
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

    @ViewBuilder
    private var postsSection: some View {
        Section {
            switch model.posts.state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .failed:
                Text("Couldn't load the posts.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(posts) where posts.isEmpty:
                Text("No posts to show yet.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(posts):
                ForEach(posts) { post in
                    NavigationLink(value: AppRoute.post(post.id)) {
                        PostSummaryRow(post: post)
                    }
                }
                if model.posts.canLoadMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .task { await model.posts.loadMore() }
                }
            }
        }
    }

    @ViewBuilder
    private var equipmentSection: some View {
        Section {
            switch model.equipment {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .failed:
                Text("Couldn't load the equipment.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(items) where items.isEmpty:
                Text("No equipment to show yet.", bundle: .module).foregroundStyle(.secondary)
            case let .loaded(items):
                ForEach(items) { item in
                    EquipmentRow(equipment: item, catalog: model.catalog)
                }
            }
        }
    }
}
