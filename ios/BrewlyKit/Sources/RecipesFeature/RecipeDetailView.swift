import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// A reusable preparation plan with the cups brewed from it.
public struct RecipeDetailView: View {
    @State private var model: RecipeDetailViewModel
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isBrewing = false
    @State private var history: [BrewSession] = []
    @State private var historyCursor: String?
    @State private var isLoadingHistory = false
    @Environment(\.dismiss) private var dismiss

    public init(recipeID: UUID, dependencies: RecipesDependencies) {
        _model = State(initialValue: RecipeDetailViewModel(recipeID: recipeID, dependencies: dependencies))
    }

    public var body: some View {
        AsyncContentView(model.state, retry: model.load) { recipe in
            content(recipe)
        }
        .navigationTitle(model.state.value?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.isOwner {
                ToolbarItem(placement: .primaryAction) {
                    actionsMenu
                }
            }
        }
        .sheet(isPresented: $isBrewing) {
            if let recipe = model.state.value, let sessions = model.dependencies.sessions {
                GuidedBrewView(recipe: recipe, sessions: sessions) { saved in
                    history.insert(saved, at: 0)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let recipe = model.state.value {
                RecipeFormView(recipe: recipe, dependencies: model.dependencies) { updated in
                    model.replace(with: updated)
                }
            }
        }
        .confirmationDialog(
            Text("Delete this recipe?", bundle: .module),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task {
                    if await model.delete() { dismiss() }
                }
            } label: {
                Text("Delete recipe", bundle: .module)
            }
        }
        .task {
            await model.load()
            await loadHistory(replacing: true)
        }
    }

    private var actionsMenu: some View {
        Menu {
            if model.isOwner {
                Button {
                    isEditing = true
                } label: {
                    Label {
                        Text("Edit", bundle: .module)
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label {
                        Text("Delete recipe", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func content(_ recipe: Recipe) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(recipe.title).font(.title2.bold())
                    Text(model.method?.localizedName ?? recipe.methodSlug)
                        .foregroundStyle(.secondary)
                    if let description = recipe.description {
                        Text(description)
                    }
                    RecipeParametersRow(
                        doseG: recipe.doseG,
                        ratio: recipe.ratio,
                        grindSize: recipe.grindSize,
                        waterTempC: recipe.waterTempC,
                        totalTimeS: recipe.totalTimeS
                    )
                }
                if model.isOwner && model.dependencies.sessions != nil {
                    Button { isBrewing = true } label: {
                        Label { Text("Start brewing", bundle: .module) } icon: { Image(systemName: "timer") }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section {
                value("Bean", recipe.bean.name)
                value("Roaster", recipe.bean.roaster)
                value("Farm", recipe.bean.farm)
                value("Country", model.catalog.country(recipe.bean.countryCode)?.localizedName)
                value("Varietals", recipe.bean.varietalSlugs.compactMap { model.catalog.varietal($0)?.name }.joined(separator: ", "))
                value("Process", model.catalog.processingMethod(recipe.bean.processingMethodSlug)?.localizedName)
            } header: {
                Text("Coffee", bundle: .module)
            }

            Section {
                value("Dose", BrewFormat.grams(recipe.doseG))
                value("Brew water", recipe.waterG.map(BrewFormat.grams))
                value("Beverage", recipe.yieldG.map(BrewFormat.grams))
                value("Ratio", BrewFormat.ratio(recipe.ratio))
                value("Grind", recipe.grindSize.localizedName)
                value("Grinder", model.catalog.grinder(recipe.grinderSlug)?.displayName)
                value("Grind setting", recipe.grindSetting)
                value("Grind size (µm)", recipe.grindMicrons.map { "\($0) µm" })
                value("Water temperature", recipe.waterTempC.map(BrewFormat.temperature))
                value("Bloom", bloomText(recipe))
                value("Total time", recipe.totalTimeS.map(BrewFormat.duration))
                value("Pressure", recipe.pressureBar.map { BrewFormat.number($0, maxFractionDigits: 1) + " bar" })
                value("Filter", recipe.filterType?.localizedName)
                value("Water", recipe.waterProfile)
                value("Water TDS", recipe.waterTdsPpm.map { "\($0) ppm" })
            } header: {
                Text("Parameters", bundle: .module)
            }

            if !recipe.steps.isEmpty {
                Section {
                    ForEach(recipe.steps, id: \.position) { step in
                        StepRow(step: step)
                    }
                } header: {
                    Text("Steps", bundle: .module)
                }
            }

            if model.isOwner {
                Section {
                    if history.count >= 2,
                       let comparison = BrewCoach.compare(history[0], with: history[1]) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Compared with the previous cup", bundle: .module).font(.headline)
                            Text("Changed settings: \(comparison.changedVariables.count)", bundle: .module)
                            if let change = comparison.ratingChange {
                                Text("Rating change: \(change)", bundle: .module)
                            }
                            HStack(alignment: .top, spacing: Spacing.m) {
                                comparisonColumn(history[1], title: String(localized: "Previous", bundle: .module))
                                comparisonColumn(history[0], title: String(localized: "Latest", bundle: .module))
                            }
                            .padding(.top, Spacing.xs)
                        }
                    }
                    if history.isEmpty {
                        Text("No cups recorded yet.", bundle: .module).foregroundStyle(.secondary)
                    }
                    ForEach(history) { session in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(session.createdAt, style: .date).font(.headline)
                            Text("\(BrewFormat.grams(session.doseG)) · \(BrewFormat.duration(session.elapsedS))")
                            if let rating = session.rating {
                                Text("Rating: \(rating)/5", bundle: .module)
                            }
                            if let notes = session.notes { Text(notes).foregroundStyle(.secondary) }
                        }
                    }
                    if historyCursor != nil {
                        Button { Task { await loadHistory(replacing: false) } } label: {
                            Text("Load older cups", bundle: .module)
                        }
                        .disabled(isLoadingHistory)
                    }
                    FieldErrorText(model.errorMessage)
                } header: { Text("Brew history", bundle: .module) }
            }
        }
    }

    @ViewBuilder
    private func value(_ title: LocalizedStringKey, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent {
                Text(value)
            } label: {
                Text(title, bundle: .module)
            }
        }
    }

    private func bloomText(_ recipe: Recipe) -> String? {
        switch (recipe.bloomWaterG, recipe.bloomTimeS) {
        case let (water?, time?): "\(BrewFormat.grams(water)) · \(time) s"
        case let (water?, nil): BrewFormat.grams(water)
        case let (nil, time?): "\(time) s"
        case (nil, nil): nil
        }
    }

    private func comparisonColumn(_ cup: BrewSession, title: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.subheadline.bold())
            Text(BrewFormat.grams(cup.doseG))
            if let water = cup.waterG { Text(BrewFormat.grams(water)) }
            if let grind = cup.grindSetting { Text(grind) }
            if let temperature = cup.waterTempC { Text(BrewFormat.temperature(temperature)) }
            Text(BrewFormat.duration(cup.elapsedS))
            if let rating = cup.rating { Text("Rating: \(rating)/5", bundle: .module) }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadHistory(replacing: Bool) async {
        guard !isLoadingHistory, let recipeID = model.state.value?.id,
              let sessions = model.dependencies.sessions else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            let page = try await sessions.sessions(recipeID: recipeID, cursor: replacing ? nil : historyCursor)
            history = replacing ? page.items : history + page.items
            historyCursor = page.nextCursor
        } catch {
            historyCursor = nil
        }
    }
}

private struct StepRow: View {
    let step: RecipeStep

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Text(BrewFormat.duration(step.startS))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(step.kind.localizedName).bold()
                    if let target = step.waterTargetG {
                        Text(verbatim: "→ \(BrewFormat.grams(target))").foregroundStyle(Color.brewlyAccent)
                    }
                }
                if let instruction = step.instruction {
                    Text(instruction).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}
