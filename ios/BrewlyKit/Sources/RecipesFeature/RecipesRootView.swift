import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Root of the Recipes tab: the user's private preparation plans.
public struct RecipesRootView: View {
    @State private var model: RecipeListViewModel
    @State private var isCreating = false

    public init(dependencies: RecipesDependencies) {
        _model = State(initialValue: RecipeListViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            AsyncContentView(model.state, retry: model.load) { recipes in
                if recipes.isEmpty {
                    emptyState
                } else {
                    list(recipes)
                }
            }
            .navigationTitle(Text("Recipes", bundle: .module))
            .navigationDestination(for: RecipeSummary.self) { summary in
                RecipeDetailView(recipeID: summary.id, dependencies: model.dependencies)
            }
            .appRouteDestinations()
            .toolbar {
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
        }
    }

    private func list(_ recipes: [RecipeSummary]) -> some View {
        List {
            ForEach(recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecipeSummaryRow(recipe: recipe, catalog: model.catalog, showsAuthor: false)
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

    private var emptyState: some View {
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
    }
}
