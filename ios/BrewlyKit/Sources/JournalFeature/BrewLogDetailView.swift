import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// A journal entry: parameters, tasting and notes. Its owner can edit or delete it.
public struct BrewLogDetailView: View {
    @State private var model: BrewLogDetailViewModel
    @State private var isEditing = false
    @State private var isConfirmingDeletion = false
    @Environment(\.dismiss) private var dismiss

    public init(brewID: UUID, dependencies: JournalDependencies) {
        _model = State(initialValue: BrewLogDetailViewModel(brewID: brewID, dependencies: dependencies))
    }

    public var body: some View {
        AsyncContentView(model.state, retry: model.load) { brew in
            List {
                if let photo = brew.photoURL {
                    Section {
                        Color.clear
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .overlay { RemoteImage(url: photo) }
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                }
                Section {
                    row(Text("Bean", bundle: .module), brew.bean.name)
                    row(Text("Method", bundle: .module), model.catalog.brewMethod(brew.methodSlug)?.localizedName)
                    if let recipe = brew.recipe {
                        NavigationLink(value: AppRoute.recipe(recipe.id)) {
                            row(Text("Recipe", bundle: .module), recipe.title)
                        }
                    }
                    row(Text("Grinder", bundle: .module), model.equipmentName)
                    row(Text("Brewed", bundle: .module), brew.brewedAt.formatted(date: .abbreviated, time: .shortened))
                    if !model.isMine {
                        NavigationLink(value: AppRoute.member(brew.user.id)) {
                            MemberRow(member: brew.user)
                        }
                    }
                }
                Section {
                    row(Text("Dose", bundle: .module), BrewFormat.grams(brew.doseG))
                    row(Text("Water", bundle: .module), brew.waterG.map(BrewFormat.grams))
                    row(Text("Beverage", bundle: .module), brew.yieldG.map(BrewFormat.grams))
                    row(Text("Ratio", bundle: .module), brew.ratio.map(BrewFormat.ratio))
                    row(Text("Grind size", bundle: .module), brew.grindSize?.localizedName)
                    row(Text("Grinder setting", bundle: .module), brew.grindSetting)
                    row(Text("Water temperature", bundle: .module), brew.waterTempC.map(BrewFormat.temperature))
                    row(Text("Total time", bundle: .module), brew.totalTimeS.map(BrewFormat.duration))
                } header: {
                    Text("Parameters", bundle: .module)
                }
                Section {
                    LabeledContent {
                        RatingView(rating: brew.tasting.rating)
                    } label: {
                        Text("Rating", bundle: .module)
                    }
                    ForEach(Tasting.Attribute.allCases, id: \.self) { attribute in
                        if let score = brew.tasting[attribute] {
                            LabeledContent(attribute.localizedName) {
                                ScoreDots(score: score)
                            }
                        }
                    }
                    row(Text("TDS", bundle: .module), brew.tdsPercent.map(BrewFormat.percent))
                    row(Text("Extraction yield", bundle: .module), brew.extractionYieldPercent.map(BrewFormat.percent))
                    if !brew.flavorNoteSlugs.isEmpty {
                        row(
                            Text("Tasting notes", bundle: .module),
                            brew.flavorNoteSlugs.compactMap { model.catalog.flavorNote($0)?.localizedName }
                                .joined(separator: ", ")
                        )
                    }
                    if let notes = brew.notes {
                        Text(notes)
                    }
                } header: {
                    Text("Tasting", bundle: .module)
                }
                if model.isMine {
                    Section {
                        Button(role: .destructive) {
                            isConfirmingDeletion = true
                        } label: {
                            Text("Delete brew", bundle: .module)
                        }
                        FieldErrorText(model.errorMessage)
                    }
                }
            }
            .refreshable { await model.load() }
        }
        .navigationTitle(Text("Brew", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.isMine, model.state.value != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isEditing = true
                    } label: {
                        Text("Edit", bundle: .module)
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                BrewLogFormView(brewLog: model.state.value, dependencies: model.dependencies) { brew in
                    model.didSave(brew)
                }
            }
        }
        .confirmationDialog(
            Text("Delete this brew?", bundle: .module),
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task {
                    if await model.delete() { dismiss() }
                }
            } label: {
                Text("Delete brew", bundle: .module)
            }
        } message: {
            Text("Its dose goes back to the bean's remaining coffee.", bundle: .module)
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private func row(_ title: Text, _ value: String?) -> some View {
        if let value {
            LabeledContent {
                Text(value)
            } label: {
                title
            }
        }
    }
}
