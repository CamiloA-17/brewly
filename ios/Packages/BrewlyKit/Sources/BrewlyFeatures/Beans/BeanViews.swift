import BrewlyDomain
import SwiftUI

struct BeanListView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    @State private var beans: [CoffeeBean] = []
    @State private var bags: [BeanBag] = []
    @State private var editing: CoffeeBean?

    var body: some View {
        List {
            ForEach(beans) { bean in
                NavigationLink {
                    BeanDetailView(bean: bean) { await load() }
                } label: {
                    BeanRow(bean: bean, bags: bags.filter { $0.beanID == bean.id && $0.finishedAt == nil })
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { beans[$0].id }
                Task {
                    for id in ids { try? await dependencies.coffee.deleteBean(id: id) }
                    await load()
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if beans.isEmpty {
                ContentUnavailableView("Sin cafés", systemImage: "leaf",
                                       description: Text("Registra los granos que usas y lleva tu inventario."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo café", systemImage: "plus") {
                    if let id = session.currentUserID { editing = CoffeeBean(ownerID: id) }
                }
            }
        }
        .sheet(item: $editing) { bean in
            BeanEditorView(bean: bean) { _ in await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        beans = (try? await dependencies.coffee.beans(includeArchived: false)) ?? []
        bags = (try? await dependencies.coffee.bags(beanID: nil)) ?? []
    }
}

private struct BeanRow: View {
    let bean: CoffeeBean
    let bags: [BeanBag]

    private var remaining: Decimal { bags.reduce(0) { $0 + $1.remainingG } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bean.name).font(.headline)
                Spacer()
                VisibilityBadge(visibility: bean.visibility).labelStyle(.iconOnly)
            }
            Text([bean.roaster, bean.originSummary].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !bags.isEmpty {
                Label("\(Format.grams(remaining)) disponibles", systemImage: "bag")
                    .font(.caption)
                    .foregroundStyle(BrewlyTheme.crema)
            }
        }
    }
}

struct BeanDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(SessionStore.self) private var session

    @State var bean: CoffeeBean
    var onChange: () async -> Void

    @State private var bags: [BeanBag] = []
    @State private var isEditing = false
    @State private var newBag: BeanBag?
    @State private var isPublishing = false

    var body: some View {
        List {
            Section("Origen") {
                LabeledContent("Tostador", value: bean.roaster ?? "—")
                LabeledContent("País", value: bean.originCountry ?? "—")
                LabeledContent("Región", value: bean.region ?? "—")
                LabeledContent("Finca", value: bean.farm ?? "—")
                LabeledContent("Productor", value: bean.producer ?? "—")
                if !bean.varieties.isEmpty {
                    LabeledContent("Variedades", value: bean.varieties.joined(separator: ", "))
                }
                if let min = bean.altitudeMinM {
                    LabeledContent("Altitud", value: bean.altitudeMaxM.map { "\(min)–\($0) msnm" } ?? "\(min) msnm")
                }
            }
            Section("Perfil") {
                LabeledContent("Proceso", value: bean.process?.title ?? "—")
                LabeledContent("Tueste", value: bean.roastLevel?.title ?? "—")
                if let score = bean.scaScore {
                    LabeledContent("Puntaje SCA", value: score.formatted())
                }
                if !bean.tastingNotes.isEmpty {
                    LabeledContent("Notas", value: bean.tastingNotes.joined(separator: ", "))
                }
            }
            Section {
                ForEach(bags) { bag in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(Format.grams(bag.remainingG)) de \(Format.grams(bag.weightG))")
                            Spacer()
                            if bag.isFrozen { Image(systemName: "snowflake") }
                            if bag.finishedAt != nil { Text("Terminada").font(.caption).foregroundStyle(.secondary) }
                        }
                        ProgressView(value: bag.remainingFraction).tint(BrewlyTheme.crema)
                        if let days = bag.daysSinceRoast() {
                            Text("\(days) días desde el tueste").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { bags[$0].id }
                    Task {
                        for id in ids { try? await dependencies.coffee.deleteBag(id: id) }
                        await loadBags()
                    }
                }
                Button("Añadir bolsa", systemImage: "plus") {
                    if let owner = session.currentUserID {
                        newBag = BeanBag(beanID: bean.id, ownerID: owner, roastDate: .now, purchaseDate: .now)
                    }
                }
            } header: {
                Text("Inventario")
            } footer: {
                Text("El inventario es siempre privado. Cada preparación descuenta automáticamente los gramos usados.")
            }
        }
        .navigationTitle(bean.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Publicar", systemImage: "square.and.arrow.up") { isPublishing = true }
                Button("Editar") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            BeanEditorView(bean: bean) { saved in
                bean = saved
                await onChange()
            }
        }
        .sheet(item: $newBag) { bag in
            BagEditorView(bag: bag) { await loadBags() }
        }
        .sheet(isPresented: $isPublishing) {
            PublishView(initialKind: .bean, initialContentID: bean.id)
        }
        .task { await loadBags() }
    }

    private func loadBags() async {
        bags = (try? await dependencies.coffee.bags(beanID: bean.id)) ?? []
    }
}

struct BeanEditorView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CoffeeBean
    @State private var varieties: String
    @State private var notes: String
    @State private var errorMessage: String?
    let onSave: (CoffeeBean) async -> Void

    init(bean: CoffeeBean, onSave: @escaping (CoffeeBean) async -> Void) {
        _draft = State(initialValue: bean)
        _varieties = State(initialValue: bean.varieties.joined(separator: ", "))
        _notes = State(initialValue: bean.tastingNotes.joined(separator: ", "))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Café") {
                    TextField("Nombre", text: $draft.name)
                    TextField("Tostador", text: $draft.roaster.orEmpty)
                }
                Section("Origen") {
                    TextField("País", text: $draft.originCountry.orEmpty)
                    TextField("Región", text: $draft.region.orEmpty)
                    TextField("Finca", text: $draft.farm.orEmpty)
                    TextField("Productor", text: $draft.producer.orEmpty)
                    TextField("Variedades (separadas por coma)", text: $varieties)
                    TextField("Altitud mínima (msnm)", value: $draft.altitudeMinM, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Altitud máxima (msnm)", value: $draft.altitudeMaxM, format: .number)
                        .keyboardType(.numberPad)
                }
                Section("Perfil") {
                    Picker("Proceso", selection: $draft.process) {
                        Text("—").tag(CoffeeProcess?.none)
                        ForEach(CoffeeProcess.allCases, id: \.self) { Text($0.title).tag(CoffeeProcess?.some($0)) }
                    }
                    Picker("Tueste", selection: $draft.roastLevel) {
                        Text("—").tag(RoastLevel?.none)
                        ForEach(RoastLevel.allCases, id: \.self) { Text($0.title).tag(RoastLevel?.some($0)) }
                    }
                    TextField("Notas de cata (separadas por coma)", text: $notes)
                    TextField("Puntaje SCA", value: $draft.scaScore, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Notas personales", text: $draft.notes.orEmpty, axis: .vertical)
                }
                Section("Privacidad") {
                    VisibilityPicker(selection: $draft.visibility)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "Nuevo café" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        draft.varieties = Self.split(varieties)
        draft.tastingNotes = Self.split(notes)
        do {
            let saved = try await dependencies.coffee.saveBean(draft)
            await onSave(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func split(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

struct BagEditorView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State var bag: BeanBag
    var onSave: () async -> Void
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Peso (g)", value: $bag.weightG, format: .number)
                    .keyboardType(.decimalPad)
                    .onChange(of: bag.weightG) { _, weight in bag.remainingG = weight }
                DatePicker("Fecha de tueste", selection: Binding(
                    get: { bag.roastDate ?? .now }, set: { bag.roastDate = $0 }
                ), displayedComponents: .date)
                DatePicker("Fecha de compra", selection: Binding(
                    get: { bag.purchaseDate ?? .now }, set: { bag.purchaseDate = $0 }
                ), displayedComponents: .date)
                TextField("Precio", value: $bag.price, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Moneda (USD, EUR, COP…)", text: $bag.currency.orEmpty)
                    .textInputAutocapitalization(.characters)
                Toggle("Congelada", isOn: $bag.isFrozen)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Nueva bolsa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            do {
                                _ = try await dependencies.coffee.saveBag(bag)
                                await onSave()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
    }
}
