import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// A recipe with every parameter. Other members' recipes can be saved and remixed.
public struct RecipeDetailView: View {
    @State private var model: RecipeDetailViewModel
    @State private var isEditing = false
    @State private var isRemixing = false
    @State private var isConfirmingDelete = false
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
            if let recipe = model.state.value {
                if !model.isOwner {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await model.toggleSave() }
                        } label: {
                            Label {
                                recipe.isSaved ? Text("Unsave", bundle: .module) : Text("Save", bundle: .module)
                            } icon: {
                                Image(systemName: recipe.isSaved ? "bookmark.fill" : "bookmark")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    actionsMenu
                }
            }
        }
        .sheet(isPresented: $isRemixing) {
            if let recipe = model.state.value {
                RecipeFormView(recipe: nil, remixOf: recipe, dependencies: model.dependencies) { _ in }
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
        .task { await model.load() }
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                isRemixing = true
            } label: {
                Label {
                    Text("Remix", bundle: .module)
                } icon: {
                    Image(systemName: "arrow.triangle.branch")
                }
            }
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
                    Text(statsText(recipe))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                NavigationLink(value: AppRoute.member(recipe.author.id)) {
                    MemberRow(member: recipe.author)
                }
                if let original = recipe.forkedFrom {
                    NavigationLink(value: AppRoute.recipe(original.id)) {
                        Label {
                            Text("Remix of \(original.title) by @\(original.author.username)", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.triangle.branch")
                        }
                        .font(.subheadline)
                    }
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

            Section {
                value("TDS", recipe.tdsPercent.map(BrewFormat.percent))
                value("Extraction yield", recipe.extractionYieldPercent.map(BrewFormat.percent))
                if let rating = recipe.rating {
                    LabeledContent {
                        RatingView(rating: rating)
                    } label: {
                        Text("Rating", bundle: .module)
                    }
                }
                if !recipe.flavorNoteSlugs.isEmpty {
                    Text(recipe.flavorNoteSlugs.compactMap { model.catalog.flavorNote($0)?.localizedName }.joined(separator: " · "))
                }
                if let notes = recipe.notes {
                    Text(notes)
                }
                FieldErrorText(model.errorMessage)
            } header: {
                Text("Results", bundle: .module)
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

    private func statsText(_ recipe: Recipe) -> String {
        let saves = String(localized: "\(recipe.saveCount) saves", bundle: .module)
        let remixes = String(localized: "\(recipe.forkCount) remixes", bundle: .module)
        return "\(saves) · \(remixes)"
    }

    private func bloomText(_ recipe: Recipe) -> String? {
        switch (recipe.bloomWaterG, recipe.bloomTimeS) {
        case let (water?, time?): "\(BrewFormat.grams(water)) · \(time) s"
        case let (water?, nil): BrewFormat.grams(water)
        case let (nil, time?): "\(time) s"
        case (nil, nil): nil
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
