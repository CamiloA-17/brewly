import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Daily starting point: return to a recipe and see what happened last time.
public struct BrewHomeView: View {
    private let dependencies: RecipesDependencies
    @State private var recipes: [RecipeSummary] = []
    @State private var latest: BrewSession?
    @State private var previous: BrewSession?
    @State private var catalog: Catalog = .empty
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCreating = false

    public init(dependencies: RecipesDependencies) { self.dependencies = dependencies }

    public var body: some View {
        NavigationStack {
            List {
                if let latest {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text(latest.recipeTitle).font(.headline)
                            Text(latest.beanName).foregroundStyle(.secondary)
                            if let rating = latest.rating {
                                Text("Rating: \(rating)/5", bundle: .module)
                            }
                            if let comparison = previous.flatMap({ BrewCoach.compare(latest, with: $0) }) {
                                Text("Changed settings: \(comparison.changedVariables.count)", bundle: .module)
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if let suggestion = BrewCoach.suggestion(for: latest, comparedWith: previous) {
                                Text(suggestionText(suggestion))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.brewlyAccent)
                            }
                            if let id = latest.recipeID {
                                NavigationLink(value: AppRoute.recipe(id)) {
                                    Text("Prepare again", bundle: .module)
                                }
                            }
                        }
                    } header: { Text("Last cup", bundle: .module) }
                }
                if let sessions = dependencies.sessions {
                    Section {
                        NavigationLink {
                            BrewHistoryView(sessions: sessions)
                        } label: {
                            Label { Text("All cups", bundle: .module) } icon: { Image(systemName: "clock.arrow.circlepath") }
                        }
                    }
                }
                Section {
                    if recipes.isEmpty && !isLoading {
                        Text("Create a recipe to start preparing and comparing cups.", bundle: .module)
                            .foregroundStyle(.secondary)
                        Button { isCreating = true } label: { Text("New recipe", bundle: .module) }
                    }
                    ForEach(recipes) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeSummaryRow(recipe: recipe, catalog: catalog, showsAuthor: false)
                        }
                    }
                } header: { Text("Your recipes", bundle: .module) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle(Text("Brew today", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: {
                        Label { Text("New recipe", bundle: .module) } icon: { Image(systemName: "plus") }
                    }
                }
            }
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipeID: recipe.id, dependencies: dependencies)
            }
            .appRouteDestinations()
            .sheet(isPresented: $isCreating) {
                RecipeFormView(recipe: nil, dependencies: dependencies) { _ in Task { await load() } }
            }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let recipePage = dependencies.recipes.myRecipes(cursor: nil)
            async let loadedCatalog = dependencies.catalog.catalog()
            let (page, catalog) = try await (recipePage, loadedCatalog)
            recipes = page.items
            self.catalog = catalog
            latest = try await dependencies.sessions?.sessions(recipeID: nil, cursor: nil).items.first
            if let latest, let recipeID = latest.recipeID {
                let recipeHistory = try await dependencies.sessions?.sessions(recipeID: recipeID, cursor: nil)
                previous = recipeHistory?.items.first(where: { $0.id != latest.id })
            } else {
                previous = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func suggestionText(_ suggestion: BrewCoach.Suggestion) -> String {
        switch suggestion {
        case .repeatBest:
            String(localized: "You liked this cup. Repeat the same settings to check consistency.", bundle: .module)
        case .tryFinerGrind:
            String(localized: "Your cup was very acidic. Try a slightly finer grind and keep other settings the same.", bundle: .module)
        case .tryCoarserGrind:
            String(localized: "Your cup was very bitter. Try a slightly coarser grind and keep other settings the same.", bundle: .module)
        case .changeOneVariable:
            String(localized: "Change one variable next time, then compare the cups.", bundle: .module)
        }
    }
}
