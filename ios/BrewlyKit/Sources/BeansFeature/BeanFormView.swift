import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Creates or edits a coffee bean.
struct BeanFormView: View {
    @State private var model: BeanFormViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: @MainActor (Bean) -> Void

    init(bean: Bean?, dependencies: BeansDependencies, onSaved: @escaping @MainActor (Bean) -> Void) {
        _model = State(initialValue: BeanFormViewModel(bean: bean, dependencies: dependencies))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                coffeeSection
                originSection
                processSection
                roastSection
                notesSection
                if let errorMessage = model.errorMessage {
                    Section { FieldErrorText(errorMessage) }
                }
            }
            .navigationTitle(model.isEditing ? Text("Edit bean", bundle: .module) : Text("New bean", bundle: .module))
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
                    if model.isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                if let bean = await model.save() {
                                    onSaved(bean)
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Save", bundle: .module)
                        }
                    }
                }
            }
            .task { await model.loadCatalog() }
        }
    }

    private var coffeeSection: some View {
        Section {
            TextField(String(localized: "Name", bundle: .module), text: $model.draft.name)
            FieldErrorText(model.message(for: "name"))
            TextField(String(localized: "Roaster", bundle: .module), text: $model.draft.roaster)
            FieldErrorText(model.message(for: "roaster"))
            Picker(selection: $model.draft.visibility) {
                ForEach(Visibility.allCases, id: \.self) { visibility in
                    Label(visibility.localizedName, systemImage: visibility.systemImage).tag(visibility)
                }
            } label: {
                Text("Visible to", bundle: .module)
            }
            if model.isEditing {
                Toggle(isOn: $model.draft.isArchived) {
                    Text("Archived", bundle: .module)
                }
            }
        } header: {
            Text("Coffee", bundle: .module)
        }
    }

    private var originSection: some View {
        Section {
            Picker(selection: $model.draft.countryCode) {
                Text("Not specified", bundle: .module).tag(String?.none)
                ForEach(sortedCountries) { country in
                    Text(country.localizedName).tag(Optional(country.code))
                }
            } label: {
                Text("Country", bundle: .module)
            }
            TextField(String(localized: "Region", bundle: .module), text: $model.draft.region)
            TextField(String(localized: "Farm", bundle: .module), text: $model.draft.farm)
            FieldErrorText(model.message(for: "farm"))
            TextField(String(localized: "Producer", bundle: .module), text: $model.draft.producer)
            HStack {
                TextField(String(localized: "Min. altitude (m)", bundle: .module), value: $model.draft.altitudeMinM, format: .number)
                    .keyboardType(.numberPad)
                TextField(String(localized: "Max. altitude (m)", bundle: .module), value: $model.draft.altitudeMaxM, format: .number)
                    .keyboardType(.numberPad)
            }
            FieldErrorText(model.message(for: "altitudeMinM") ?? model.message(for: "altitudeMaxM"))
        } header: {
            Text("Origin", bundle: .module)
        }
    }

    private var processSection: some View {
        Section {
            NavigationLink {
                MultiSelectionList(items: model.catalog.varietals, selection: $model.draft.varietalSlugs) {
                    $0.name
                } subtitle: {
                    $0.species.localizedName
                }
                .navigationTitle(Text("Varietals", bundle: .module))
            } label: {
                LabeledContent {
                    Text(selectedNames(model.draft.varietalSlugs) { model.catalog.varietal($0)?.name })
                } label: {
                    Text("Varietals", bundle: .module)
                }
            }
            Picker(selection: $model.draft.processingMethodSlug) {
                Text("Not specified", bundle: .module).tag(String?.none)
                ForEach(model.catalog.processingMethods) { process in
                    Text(process.localizedName).tag(Optional(process.slug))
                }
            } label: {
                Text("Process", bundle: .module)
            }
            TextField(String(localized: "Harvest year", bundle: .module), value: $model.draft.harvestYear, format: .number.grouping(.never))
                .keyboardType(.numberPad)
            FieldErrorText(model.message(for: "harvestYear"))
            TextField(String(localized: "SCA score", bundle: .module), value: $model.draft.scaScore, format: .number)
                .keyboardType(.decimalPad)
            FieldErrorText(model.message(for: "scaScore"))
            Toggle(isOn: $model.draft.isDecaf) {
                Text("Decaf", bundle: .module)
            }
        } header: {
            Text("Coffee details", bundle: .module)
        }
    }

    private var roastSection: some View {
        Section {
            Picker(selection: $model.draft.roastLevel) {
                Text("Not specified", bundle: .module).tag(RoastLevel?.none)
                ForEach(RoastLevel.allCases, id: \.self) { level in
                    Text(level.localizedName).tag(Optional(level))
                }
            } label: {
                Text("Roast level", bundle: .module)
            }
            Toggle(isOn: hasRoastDate) {
                Text("I know the roast date", bundle: .module)
            }
            if model.draft.roastDate != nil {
                DatePicker(selection: roastDate, in: ...Date(), displayedComponents: .date) {
                    Text("Roast date", bundle: .module)
                }
            }
            FieldErrorText(model.message(for: "roastDate"))
            TextField(String(localized: "Bag weight (g)", bundle: .module), value: $model.draft.weightG, format: .number)
                .keyboardType(.numberPad)
            FieldErrorText(model.message(for: "weightG"))
        } header: {
            Text("Roast", bundle: .module)
        }
    }

    private var notesSection: some View {
        Section {
            NavigationLink {
                MultiSelectionList(items: model.catalog.flavorNotes, selection: $model.draft.flavorNoteSlugs) {
                    $0.localizedName
                } subtitle: {
                    $0.category.localizedName
                }
                .navigationTitle(Text("Tasting notes", bundle: .module))
            } label: {
                LabeledContent {
                    Text(selectedNames(model.draft.flavorNoteSlugs) { model.catalog.flavorNote($0)?.localizedName })
                } label: {
                    Text("Tasting notes", bundle: .module)
                }
            }
            TextField(String(localized: "Notes", bundle: .module), text: $model.draft.notes, axis: .vertical)
                .lineLimit(3...8)
            FieldErrorText(model.message(for: "notes"))
        } header: {
            Text("Notes", bundle: .module)
        }
    }

    private var sortedCountries: [Country] {
        model.catalog.countries.sorted { $0.localizedName.localizedCompare($1.localizedName) == .orderedAscending }
    }

    private var hasRoastDate: Binding<Bool> {
        Binding {
            model.draft.roastDate != nil
        } set: { isOn in
            model.draft.roastDate = isOn ? .today() : nil
        }
    }

    private var roastDate: Binding<Date> {
        Binding {
            model.draft.roastDate?.date() ?? Date()
        } set: { date in
            model.draft.roastDate = CalendarDate(date: date)
        }
    }

    private func selectedNames(_ slugs: Set<String>, name: (String) -> String?) -> String {
        slugs.compactMap(name).sorted().joined(separator: ", ")
    }
}
