import BrewlyDomain
import SwiftUI

struct RecipeListView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    @State private var recipes: [Recipe] = []
    @State private var catalog = LibraryCatalog()
    @State private var editing: Recipe?

    var body: some View {
        List {
            ForEach(recipes) { recipe in
                NavigationLink(value: recipe) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recipe.title).font(.headline)
                            Spacer()
                            VisibilityBadge(visibility: recipe.visibility).labelStyle(.iconOnly)
                        }
                        Text([recipe.method?.name, recipe.bean?.name].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(Format.grams(recipe.doseG)) · \(Format.ratio(recipe.ratio)) · \(Format.duration(recipe.totalTimeS))")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { recipes[$0].id }
                Task {
                    for id in ids { try? await dependencies.recipes.delete(id: id) }
                    await load()
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if recipes.isEmpty {
                ContentUnavailableView("Sin recetas", systemImage: "list.bullet.rectangle",
                                       description: Text("Crea tu primera receta o guarda una de la comunidad."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nueva receta", systemImage: "plus") { startNew() }
                    .disabled(catalog.methods.isEmpty)
            }
        }
        .sheet(item: $editing) { recipe in
            RecipeEditorView(recipe: recipe, catalog: catalog) { _ in await load() }
        }
        .task {
            await catalog.load(using: dependencies.coffee)
            await load()
        }
        .refreshable { await load() }
    }

    private func load() async {
        recipes = (try? await dependencies.recipes.myRecipes()) ?? []
    }

    private func startNew() {
        guard let owner = session.currentUserID, let method = catalog.methods.first else { return }
        let params = method.defaultParams
        editing = Recipe(
            ownerID: owner,
            brewMethodID: method.id,
            doseG: params.doseG ?? 15,
            waterG: params.waterG,
            yieldG: params.yieldG,
            waterTempC: params.tempC,
            totalTimeS: params.timeS
        )
    }
}

struct RecipeDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    let recipeID: UUID
    @State var preview: Recipe?

    @State private var recipe: Recipe?
    @State private var catalog = LibraryCatalog()
    @State private var targetDose: Decimal?
    @State private var isEditing = false
    @State private var isBrewing = false
    @State private var isPublishing = false
    @State private var message: String?

    private var shown: Recipe? {
        guard let base = recipe ?? preview else { return nil }
        if let targetDose, targetDose != base.doseG {
            return BrewMath.scale(base, toDose: targetDose)
        }
        return base
    }

    private var isMine: Bool { (recipe ?? preview)?.ownerID == session.currentUserID }

    var body: some View {
        Group {
            if let shown {
                content(shown)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(shown?.title ?? "Receta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isMine {
                    Button("Publicar", systemImage: "square.and.arrow.up") { isPublishing = true }
                    Button("Editar") { isEditing = true }
                } else {
                    Button("Guardar copia", systemImage: "square.on.square") { Task { await fork() } }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let recipe {
                RecipeEditorView(recipe: recipe, catalog: catalog) { saved in self.recipe = saved }
            }
        }
        .fullScreenCover(isPresented: $isBrewing) {
            if let shown {
                BrewTimerView(recipe: shown)
            }
        }
        .sheet(isPresented: $isPublishing) {
            PublishView(initialKind: .recipe, initialContentID: recipeID)
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .task {
            recipe = try? await dependencies.recipes.recipe(id: recipeID)
            if isMine { await catalog.load(using: dependencies.coffee) }
        }
    }

    private func content(_ recipe: Recipe) -> some View {
        List {
            Section {
                RecipeSummaryView(recipe: recipe)
                if let description = recipe.description {
                    Text(description)
                }
                if let bean = recipe.bean {
                    LabeledContent("Café", value: bean.name)
                }
                if let grind = recipe.grindSetting ?? recipe.grindSize {
                    LabeledContent("Molienda", value: grind)
                }
            }

            Section("Escalar receta") {
                Stepper(value: Binding(
                    get: { NSDecimalNumber(decimal: targetDose ?? recipe.doseG).doubleValue },
                    set: { targetDose = Decimal($0.rounded()) }
                ), in: 5...100, step: 1) {
                    Text("Dosis: \(Format.grams(targetDose ?? recipe.doseG))")
                }
            }

            Section("Pasos") {
                ForEach(recipe.steps) { step in
                    HStack(alignment: .top) {
                        Text(Format.duration(step.startAtS))
                            .font(.caption.monospacedDigit())
                            .frame(width: 44, alignment: .leading)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(step.kind.title).font(.caption.bold()).foregroundStyle(BrewlyTheme.crema)
                            Text(step.instruction)
                        }
                        Spacer()
                        if let water = step.waterG {
                            Text(Format.grams(water)).font(.callout.monospacedDigit())
                        }
                    }
                }
            }

            Section {
                Button {
                    isBrewing = true
                } label: {
                    Label("Preparar ahora", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func fork() async {
        do {
            let copy = try await dependencies.recipes.fork(id: recipeID)
            message = "\"\(copy.title)\" se guardó en tu barra como receta privada."
        } catch {
            message = error.localizedDescription
        }
    }
}

struct RecipeEditorView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Recipe
    @State private var errorMessage: String?
    @State private var isSaving = false
    let catalog: LibraryCatalog
    let onSave: (Recipe) async -> Void

    init(recipe: Recipe, catalog: LibraryCatalog, onSave: @escaping (Recipe) async -> Void) {
        _draft = State(initialValue: recipe)
        self.catalog = catalog
        self.onSave = onSave
    }

    private var isEspresso: Bool { catalog.method(id: draft.brewMethodID)?.category == .espresso }

    var body: some View {
        NavigationStack {
            Form {
                Section("Receta") {
                    TextField("Título", text: $draft.title)
                    TextField("Descripción", text: $draft.description.orEmpty, axis: .vertical)
                        .lineLimit(2...6)
                    Picker("Método", selection: $draft.brewMethodID) {
                        ForEach(catalog.methods) { Text($0.name).tag($0.id) }
                    }
                    Picker("Café", selection: $draft.beanID) {
                        Text("Ninguno").tag(UUID?.none)
                        ForEach(catalog.beans) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    Picker("Molino", selection: $draft.grinderID) {
                        Text("Ninguno").tag(UUID?.none)
                        ForEach(catalog.grinders) { Text($0.displayName).tag(UUID?.some($0.id)) }
                    }
                }

                Section {
                    LabeledField("Dosis (g)", value: $draft.doseG)
                    if isEspresso {
                        LabeledField("Rendimiento (g)", value: $draft.yieldG)
                    } else {
                        LabeledField("Agua (g)", value: $draft.waterG)
                    }
                    LabeledField("Temperatura (°C)", value: $draft.waterTempC)
                    TextField("Molienda (p. ej. 22 clics)", text: $draft.grindSetting.orEmpty)
                    TextField("Tiempo total (s)", value: $draft.totalTimeS, format: .number)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Parámetros")
                } footer: {
                    if !isEspresso, let ratio = draft.computedRatio {
                        Text("Relación \(Format.ratio(ratio))")
                    }
                }

                Section {
                    ForEach($draft.steps) { $step in
                        StepEditorRow(step: $step)
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                    Button("Añadir paso", systemImage: "plus") {
                        let last = draft.steps.last
                        draft.steps.append(RecipeStep(
                            position: draft.steps.count,
                            kind: draft.steps.isEmpty ? .bloom : .pour,
                            startAtS: last.map { ($0.startAtS ?? 0) + ($0.durationS ?? 30) } ?? 0
                        ))
                    }
                } header: {
                    HStack {
                        Text("Pasos")
                        Spacer()
                        EditButton().font(.caption)
                    }
                }

                Section("Privacidad") {
                    VisibilityPicker(selection: $draft.visibility)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(draft.title.isEmpty ? "Nueva receta" : draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        for index in draft.steps.indices { draft.steps[index].position = index }
        do {
            let saved = try await dependencies.recipes.save(draft)
            await onSave(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct StepEditorRow: View {
    @Binding var step: RecipeStep

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Tipo", selection: $step.kind) {
                ForEach(StepKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            TextField("Instrucción", text: $step.instruction, axis: .vertical)
            HStack {
                TextField("Agua (g)", value: $step.waterG, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Inicio (s)", value: $step.startAtS, format: .number)
                    .keyboardType(.numberPad)
                TextField("Duración (s)", value: $step.durationS, format: .number)
                    .keyboardType(.numberPad)
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}

/// Campo numérico decimal con etiqueta a la izquierda.
struct LabeledField: View {
    let title: String
    @Binding var value: Decimal?

    init(_ title: String, value: Binding<Decimal?>) {
        self.title = title
        _value = value
    }

    init(_ title: String, value: Binding<Decimal>) {
        self.title = title
        _value = Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0 ?? 0 })
    }

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
