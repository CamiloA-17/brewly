import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// The signed-in user's gear, grouped by kind.
struct EquipmentListView: View {
    @State private var model: EquipmentListViewModel
    @State private var editing: EditTarget?
    private let equipment: any EquipmentRepository

    private enum EditTarget: Identifiable {
        case new
        case existing(Equipment)

        var id: String {
            switch self {
            case .new: "new"
            case let .existing(item): item.id.uuidString
            }
        }

        var item: Equipment? {
            if case let .existing(item) = self { return item }
            return nil
        }
    }

    init(equipment: any EquipmentRepository, catalog: any CatalogRepository) {
        _model = State(initialValue: EquipmentListViewModel(equipment: equipment, catalog: catalog))
        self.equipment = equipment
    }

    var body: some View {
        AsyncContentView(model.state, retry: model.load) { items in
            List {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No equipment yet", bundle: .module)
                        } icon: {
                            Image(systemName: "gearshape.2")
                        }
                    } description: {
                        Text("Add your grinder and its usual setting per method to pre-fill your recipes.", bundle: .module)
                    }
                }
                ForEach(EquipmentKind.allCases, id: \.self) { kind in
                    let group = items.filter { $0.kind == kind }
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { item in
                                Button {
                                    editing = .existing(item)
                                } label: {
                                    EquipmentRow(equipment: item, catalog: model.catalog)
                                }
                                .tint(.primary)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await model.delete(item) }
                                    } label: {
                                        Text("Delete", bundle: .module)
                                    }
                                }
                            }
                        } header: {
                            Text(kind.localizedName)
                        }
                    }
                }
                FieldErrorText(model.errorMessage)
            }
        }
        .navigationTitle(Text("My equipment", bundle: .module))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = .new
                } label: {
                    Label {
                        Text("Add equipment", bundle: .module)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .disabled(model.state.value == nil)
            }
        }
        .sheet(item: $editing) { target in
            EquipmentFormView(item: target.item, catalog: model.catalog, equipment: equipment) {
                editing = nil
                Task { await model.load() }
            }
        }
        .task { await model.load() }
    }
}

/// Adds or edits an item of gear. Grinders can name a catalog model and keep a setting per method.
struct EquipmentFormView: View {
    @State private var model: EquipmentFormViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: @MainActor () -> Void

    init(item: Equipment?, catalog: Catalog, equipment: any EquipmentRepository, onSaved: @escaping @MainActor () -> Void) {
        _model = State(initialValue: EquipmentFormViewModel(item: item, catalog: catalog, equipment: equipment))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $model.draft.kind) {
                        ForEach(EquipmentKind.allCases, id: \.self) { kind in
                            Label(kind.localizedName, systemImage: kind.systemImage).tag(kind)
                        }
                    } label: {
                        Text("Type", bundle: .module)
                    }
                    if model.draft.kind == .grinder {
                        Picker(selection: $model.draft.grinderSlug) {
                            Text("Not in the list", bundle: .module).tag(String?.none)
                            ForEach(model.catalog.grinders) { grinder in
                                Text(grinder.displayName).tag(Optional(grinder.slug))
                            }
                        } label: {
                            Text("Model", bundle: .module)
                        }
                        .pickerStyle(.navigationLink)
                        FieldErrorText(model.message(for: "grinderSlug"))
                    }
                    if !model.usesCatalogGrinder {
                        TextField(String(localized: "Brand", bundle: .module), text: $model.draft.brand)
                        FieldErrorText(model.message(for: "brand"))
                        TextField(String(localized: "Model", bundle: .module), text: $model.draft.model)
                        FieldErrorText(model.message(for: "model"))
                    }
                    TextField(String(localized: "Nickname (optional)", bundle: .module), text: $model.draft.nickname)
                    FieldErrorText(model.message(for: "nickname"))
                    Toggle(isOn: $model.draft.isDefault) {
                        Text("Use by default", bundle: .module)
                    }
                } footer: {
                    Text("Your equipment is shown on your profile.", bundle: .module)
                }

                if model.draft.kind == .grinder {
                    Section {
                        ForEach(model.catalog.brewMethods) { method in
                            LabeledContent(method.localizedName) {
                                TextField(
                                    String(localized: "e.g. 24 clicks", bundle: .module),
                                    text: settingBinding(for: method.slug)
                                )
                                .multilineTextAlignment(.trailing)
                            }
                        }
                        FieldErrorText(model.violations.first { $0.field.hasPrefix("grindSettings") }?.localizedMessage)
                    } header: {
                        Text("Usual grind setting", bundle: .module)
                    } footer: {
                        Text("New recipes with your default grinder start with this setting.", bundle: .module)
                    }
                }

                Section {
                    TextField(String(localized: "Notes", bundle: .module), text: $model.draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                    FieldErrorText(model.message(for: "notes"))
                    FieldErrorText(model.errorMessage)
                }
            }
            .navigationTitle(model.isEditing
                ? Text("Edit equipment", bundle: .module)
                : Text("Add equipment", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await model.save() != nil { onSaved() }
                        }
                    } label: {
                        Text("Save", bundle: .module)
                    }
                    .disabled(model.isSaving)
                }
            }
        }
    }

    private func settingBinding(for methodSlug: String) -> Binding<String> {
        Binding(
            get: { model.draft.grindSettings[methodSlug] ?? "" },
            set: { model.draft.grindSettings[methodSlug] = $0 }
        )
    }
}
