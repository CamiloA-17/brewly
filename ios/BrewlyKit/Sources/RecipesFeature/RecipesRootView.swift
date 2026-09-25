import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Root of the Recipes tab: the user's recipes and the community's public ones.
public struct RecipesRootView: View {
    @State private var model: RecipeListViewModel
    @State private var isCreating = false

    public init(dependencies: RecipesDependencies) {
        _model = State(initialValue: RecipeListViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(selection: $model.scope) {
                    Text("My recipes", bundle: .module).tag(RecipeListViewModel.Scope.mine)
                    Text("Explore", bundle: .module).tag(RecipeListViewModel.Scope.explore)
                } label: {
                    Text("Recipes", bundle: .module)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, Spacing.s)

                AsyncContentView(model.state, retry: model.load) { recipes in
                    if recipes.isEmpty {
                        emptyState
                    } else {
                        list(recipes)
                    }
                }
            }
            .navigationTitle(Text("Recipes", bundle: .module))
            .navigationDestination(for: RecipeSummary.self) { summary in
                RecipeDetailView(recipeID: summary.id, dependencies: model.dependencies)
            }
            .toolbar {
                if model.scope == .explore {
                    ToolbarItem(placement: .topBarLeading) {
                        methodFilterMenu
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Label {
                            Text("New recipe", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isCreating) {
                RecipeFormView(recipe: nil, dependencies: model.dependencies) { _ in
                    Task { await model.load() }
                }
            }
            .task { await model.load() }
            .onChange(of: model.scope) {
                Task { await model.load() }
            }
            .onChange(of: model.methodFilter) {
                Task { await model.load() }
            }
        }
    }

    private func list(_ recipes: [RecipeSummary]) -> some View {
        List {
            ForEach(recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecipeRow(recipe: recipe, catalog: model.catalog, showsAuthor: model.scope == .explore)
                }
            }
            if model.canLoadMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task { await model.loadMore() }
            }
        }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.scope {
        case .mine:
            ContentUnavailableView {
                Label {
                    Text("No recipes yet", bundle: .module)
                } icon: {
                    Image(systemName: "cup.and.saucer")
                }
            } description: {
                Text("Create your first recipe with one of your beans and a brew method.", bundle: .module)
            } actions: {
                Button {
                    isCreating = true
                } label: {
                    Text("New recipe", bundle: .module)
                }
                .buttonStyle(.borderedProminent)
            }
        case .explore:
            ContentUnavailableView {
                Label {
                    Text("Nothing to explore yet", bundle: .module)
                } icon: {
                    Image(systemName: "globe")
                }
            } description: {
                Text("Public recipes from the community will show up here.", bundle: .module)
            }
        }
    }

    private var methodFilterMenu: some View {
        Menu {
            Picker(selection: $model.methodFilter) {
                Text("All methods", bundle: .module).tag(String?.none)
                ForEach(model.catalog.brewMethods) { method in
                    Text(method.localizedName).tag(Optional(method.slug))
                }
            } label: {
                Text("Brew method", bundle: .module)
            }
        } label: {
            Label {
                Text("Filter", bundle: .module)
            } icon: {
                Image(systemName: model.methodFilter == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: RecipeSummary
    let catalog: Catalog
    let showsAuthor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title).font(.headline)
                Spacer()
                if let rating = recipe.rating {
                    RatingView(rating: rating).font(.caption2)
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
