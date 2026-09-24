import BrewlyDomain
import SwiftUI

/// Bitácora de preparaciones + estadísticas personales.
struct BrewLogView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    @State private var brews: [Brew] = []
    @State private var stats = BrewStats()
    @State private var catalog = LibraryCatalog()
    @State private var editing: Brew?

    var body: some View {
        List {
            Section("Últimos 30 días") {
                HStack {
                    statView("\(stats.totalBrews)", "Preparaciones")
                    Divider()
                    statView(Format.grams(stats.totalCoffeeG), "Café usado")
                    Divider()
                    statView(stats.avgRating.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", "Nota media")
                }
                if let method = catalog.method(id: stats.favoriteMethodID) {
                    LabeledContent("Método favorito", value: method.name)
                }
                if let bean = catalog.bean(id: stats.favoriteBeanID) {
                    LabeledContent("Café más usado", value: bean.name)
                }
            }

            Section("Bitácora") {
                ForEach(brews) { brew in
                    Button {
                        editing = brew
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(catalog.method(id: brew.brewMethodID)?.name ?? "Preparación").font(.headline)
                                Spacer()
                                Text(brew.brewedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let bean = catalog.bean(id: brew.beanID) {
                                Text(bean.name).font(.subheadline)
                            }
                            BrewSummaryView(brew: brew)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let ids = offsets.map { brews[$0].id }
                    Task {
                        for id in ids { try? await dependencies.brews.delete(id: id) }
                        await load()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Registrar preparación", systemImage: "plus") {
                    guard let owner = session.currentUserID, let method = catalog.methods.first else { return }
                    editing = Brew(ownerID: owner, brewMethodID: method.id, doseG: method.defaultParams.doseG ?? 15)
                }
            }
        }
        .sheet(item: $editing) { brew in
            BrewEditorView(brew: brew) { _ in await load() }
        }
        .task {
            await catalog.load(using: dependencies.coffee)
            await load()
        }
        .refreshable { await load() }
    }

    private func statView(_ value: String, _ title: String) -> some View {
        VStack {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        brews = (try? await dependencies.brews.myBrews(limit: 100)) ?? []
        stats = (try? await dependencies.brews.stats(days: 30)) ?? BrewStats()
    }
}

struct BrewEditorView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Brew
    @State private var catalog = LibraryCatalog()
    @State private var bags: [BeanBag] = []
    @State private var notes: String
    @State private var shareAfterSave = false
    @State private var saved: Brew?
    @State private var errorMessage: String?
    let onSave: (Brew) async -> Void

    init(brew: Brew, onSave: @escaping (Brew) async -> Void) {
        _draft = State(initialValue: brew)
        _notes = State(initialValue: brew.tastingNotes.joined(separator: ", "))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preparación") {
                    Picker("Método", selection: $draft.brewMethodID) {
                        ForEach(catalog.methods) { Text($0.name).tag($0.id) }
                    }
                    Picker("Café", selection: $draft.beanID) {
                        Text("Ninguno").tag(UUID?.none)
                        ForEach(catalog.beans) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    Picker("Bolsa", selection: $draft.bagID) {
                        Text("No descontar").tag(UUID?.none)
                        ForEach(bags.filter { $0.beanID == draft.beanID && $0.finishedAt == nil }) { bag in
                            Text("\(Format.grams(bag.remainingG)) restantes").tag(UUID?.some(bag.id))
                        }
                    }
                    DatePicker("Fecha", selection: $draft.brewedAt)
                }
                Section("Parámetros") {
                    LabeledField("Dosis (g)", value: $draft.doseG)
                    LabeledField("Agua (g)", value: $draft.waterG)
                    LabeledField("Bebida (g)", value: $draft.yieldG)
                    LabeledField("Temperatura (°C)", value: $draft.waterTempC)
                    TextField("Molienda", text: $draft.grindSetting.orEmpty)
                    TextField("Tiempo (s)", value: $draft.totalTimeS, format: .number)
                        .keyboardType(.numberPad)
                    LabeledField("TDS (%)", value: $draft.tds)
                    if let tds = draft.tds, let beverage = draft.yieldG,
                       let ey = BrewMath.extractionYield(beverageG: beverage, tds: tds, dose: draft.doseG) {
                        LabeledContent("Extracción", value: "\(ey.formatted()) %")
                    }
                }
                Section("Cata") {
                    RatingPicker(rating: $draft.rating)
                    ScoreSlider(title: "Acidez", value: $draft.acidity)
                    ScoreSlider(title: "Dulzor", value: $draft.sweetness)
                    ScoreSlider(title: "Cuerpo", value: $draft.body)
                    ScoreSlider(title: "Amargor", value: $draft.bitterness)
                    ScoreSlider(title: "Retrogusto", value: $draft.aftertaste)
                    TextField("Notas de cata (separadas por coma)", text: $notes)
                    TextField("Comentarios", text: $draft.notes.orEmpty, axis: .vertical)
                }
                Section {
                    VisibilityPicker(selection: $draft.visibility)
                    Toggle("Publicar al guardar", isOn: $shareAfterSave)
                } header: {
                    Text("Privacidad")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Preparación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                }
            }
            .task {
                await catalog.load(using: dependencies.coffee)
                bags = (try? await dependencies.coffee.bags(beanID: nil)) ?? []
            }
            .sheet(item: $saved, onDismiss: { dismiss() }) { brew in
                PublishView(initialKind: .brew, initialContentID: brew.id)
            }
        }
    }

    private func save() async {
        draft.tastingNotes = BeanEditorView.split(notes)
        do {
            let result = try await dependencies.brews.save(draft)
            await onSave(result)
            if shareAfterSave {
                saved = result
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RatingPicker: View {
    @Binding var rating: Int?

    var body: some View {
        HStack {
            Text("Valoración")
            Spacer()
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                    .foregroundStyle(.orange)
                    .onTapGesture { rating = (rating == star) ? nil : star }
            }
        }
    }
}

private struct ScoreSlider: View {
    let title: String
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value.map(String.init) ?? "—").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { Double(value ?? 5) }, set: { value = Int($0.rounded()) }),
                in: 1...10,
                step: 1
            )
        }
    }
}
