import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Creates or edits a recipe with every brewing parameter.
struct RecipeFormView: View {
    @State private var model: RecipeFormViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: @MainActor (Recipe) -> Void

    init(recipe: Recipe?, dependencies: RecipesDependencies, onSaved: @escaping @MainActor (Recipe) -> Void) {
        _model = State(initialValue: RecipeFormViewModel(recipe: recipe, dependencies: dependencies))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.beans.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("Add a bean first", bundle: .module)
                        } icon: {
                            Image(systemName: "leaf")
                        }
                    } description: {
                        Text("Every recipe uses one of your beans. Add it in the Beans tab.", bundle: .module)
                    }
                } else {
                    form
                }
            }
            .navigationTitle(model.isEditing ? Text("Edit recipe", bundle: .module) : Text("New recipe", bundle: .module))
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
                                if let recipe = await model.save() {
                                    onSaved(recipe)
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Save", bundle: .module)
                        }
                        .disabled(model.beans.isEmpty)
                    }
                }
            }
            .task { await model.load() }
        }
    }

    private var form: some View {
        Form {
            basicsSection
            coffeeSection
            dosingSection
            grindSection
            extractionSection
            waterSection
            stepsSection
            resultsSection
            if let errorMessage = model.errorMessage {
                Section { FieldErrorText(errorMessage) }
            }
        }
    }

    // MARK: Sections

    private var basicsSection: some View {
        Section {
            TextField(String(localized: "Title", bundle: .module), text: $model.draft.title)
            FieldErrorText(model.message(for: "title"))
            TextField(String(localized: "Description", bundle: .module), text: $model.draft.description, axis: .vertical)
                .lineLimit(2...5)
            Picker(selection: $model.draft.visibility) {
                ForEach(Visibility.allCases, id: \.self) { visibility in
                    Label(visibility.localizedName, systemImage: visibility.systemImage).tag(visibility)
                }
            } label: {
                Text("Visible to", bundle: .module)
            }
        }
    }

    private var coffeeSection: some View {
        Section {
            Picker(selection: $model.draft.beanID) {
                ForEach(model.beans) { bean in
                    Text(bean.name).tag(Optional(bean.id))
                }
            } label: {
                Text("Bean", bundle: .module)
            }
            FieldErrorText(model.message(for: "beanId"))
            Picker(selection: methodSelection) {
                Text("Choose a method", bundle: .module).tag(String?.none)
                ForEach(model.methodsSortedForPicker) { method in
                    Text(method.localizedName).tag(Optional(method.slug))
                }
            } label: {
                Text("Brew method", bundle: .module)
            }
            FieldErrorText(model.message(for: "methodSlug"))
        } header: {
            Text("Coffee", bundle: .module)
        } footer: {
            if model.method != nil {
                Text("Suggested values for the method were filled in. Adjust them to your recipe.", bundle: .module)
            }
        }
    }

    private var dosingSection: some View {
        Section {
            numberField("Dose (g)", value: $model.draft.doseG, field: "doseG")
            switch model.ratioBasis {
            case .water:
                numberField("Brew water (g)", value: $model.draft.waterG, field: "waterG")
                numberField("Beverage weight (g, optional)", value: $model.draft.yieldG, field: "yieldG")
            case .beverage:
                numberField("Beverage weight (g)", value: $model.draft.yieldG, field: "yieldG")
            }
            LabeledContent {
                Text(model.draft.ratio.map(BrewFormat.ratio) ?? "—")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(Color.brewlyAccent)
            } label: {
                Text("Ratio", bundle: .module)
            }
            FieldErrorText(model.message(for: "ratio"))
        } header: {
            Text("Dosing", bundle: .module)
        } footer: {
            if model.ratioBasis == .beverage {
                Text("For espresso the ratio uses the beverage weight.", bundle: .module)
            }
        }
    }

    private var grindSection: some View {
        Section {
            Picker(selection: $model.draft.grindSize) {
                ForEach(GrindSize.allCases, id: \.self) { size in
                    Text(size.localizedName).tag(size)
                }
            } label: {
                Text("Grind size", bundle: .module)
            }
            Picker(selection: $model.draft.grinderSlug) {
                Text("Not specified", bundle: .module).tag(String?.none)
                ForEach(model.catalog.grinders) { grinder in
                    Text(grinder.displayName).tag(Optional(grinder.slug))
                }
            } label: {
                Text("Grinder", bundle: .module)
            }
            TextField(String(localized: "Grinder setting (e.g. 24 clicks)", bundle: .module), text: $model.draft.grindSetting)
            FieldErrorText(model.message(for: "grindSetting"))
            integerField("Particle size (µm)", value: $model.draft.grindMicrons, field: "grindMicrons")
        } header: {
            Text("Grind", bundle: .module)
        }
    }

    private var extractionSection: some View {
        Section {
            numberField("Water temperature (°C)", value: $model.draft.waterTempC, field: "waterTempC")
            if model.ratioBasis == .water {
                numberField("Bloom water (g)", value: $model.draft.bloomWaterG, field: "bloomWaterG")
            }
            integerField("Bloom / pre-infusion (s)", value: $model.draft.bloomTimeS, field: "bloomTimeS")
            integerField("Total time (s)", value: $model.draft.totalTimeS, field: "totalTimeS")
            if model.method?.usesPressure == true {
                numberField("Pressure (bar)", value: $model.draft.pressureBar, field: "pressureBar")
            }
            if model.ratioBasis == .water {
                Picker(selection: $model.draft.filterType) {
                    Text("Not specified", bundle: .module).tag(FilterType?.none)
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.localizedName).tag(Optional(filter))
                    }
                } label: {
                    Text("Filter", bundle: .module)
                }
            }
        } header: {
            Text("Extraction", bundle: .module)
        }
    }

    private var waterSection: some View {
        Section {
            TextField(String(localized: "Water (e.g. filtered, Third Wave Water)", bundle: .module), text: $model.draft.waterProfile)
            FieldErrorText(model.message(for: "waterProfile"))
            integerField("Water TDS (ppm)", value: $model.draft.waterTdsPpm, field: "waterTdsPpm")
        } header: {
            Text("Water", bundle: .module)
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach($model.draft.steps) { $step in
                StepEditorRow(step: $step)
            }
            .onDelete { model.removeSteps(at: $0) }
            .onMove { model.moveSteps(from: $0, to: $1) }
            Button {
                model.addStep()
            } label: {
                Label {
                    Text("Add step", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle")
                }
            }
        } header: {
            Text("Steps", bundle: .module)
        } footer: {
            Text("Water targets are the scale reading to reach during the step.", bundle: .module)
        }
    }

    private var resultsSection: some View {
        Section {
            numberField("TDS (%)", value: $model.draft.tdsPercent, field: "tdsPercent")
            LabeledContent {
                Text(model.draft.extractionYield.map(BrewFormat.percent) ?? "—")
                    .monospacedDigit()
            } label: {
                Text("Extraction yield", bundle: .module)
            }
            LabeledContent {
                RatingView(rating: $model.draft.rating)
            } label: {
                Text("Rating", bundle: .module)
            }
            NavigationLink {
                MultiSelectionList(items: model.catalog.flavorNotes, selection: $model.draft.flavorNoteSlugs) {
                    $0.localizedName
                } subtitle: {
                    $0.category.localizedName
                }
                .navigationTitle(Text("Tasting notes", bundle: .module))
            } label: {
                LabeledContent {
                    Text(model.draft.flavorNoteSlugs.compactMap { model.catalog.flavorNote($0)?.localizedName }.sorted().joined(separator: ", "))
                } label: {
                    Text("Tasting notes", bundle: .module)
                }
            }
            TextField(String(localized: "Notes", bundle: .module), text: $model.draft.notes, axis: .vertical)
                .lineLimit(2...6)
            FieldErrorText(model.message(for: "notes"))
        } header: {
            Text("Results", bundle: .module)
        } footer: {
            Text("Extraction yield is calculated from the beverage weight and TDS.", bundle: .module)
        }
    }

    // MARK: Inputs

    private var methodSelection: Binding<String?> {
        Binding {
            model.draft.methodSlug
        } set: { slug in
            model.selectMethod(slug)
        }
    }

    private func numberField(_ title: String.LocalizationValue, value: Binding<Double?>, field: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent {
                TextField(String(localized: title, bundle: .module), value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(String(localized: title, bundle: .module))
            }
            FieldErrorText(model.message(for: field))
        }
    }

    private func integerField(_ title: String.LocalizationValue, value: Binding<Int?>, field: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent {
                TextField(String(localized: title, bundle: .module), value: value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(String(localized: title, bundle: .module))
            }
            FieldErrorText(model.message(for: field))
        }
    }
}

private struct StepEditorRow: View {
    @Binding var step: RecipeDraft.Step

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Picker(selection: $step.kind) {
                ForEach(BrewStepKind.allCases, id: \.self) { kind in
                    Text(kind.localizedName).tag(kind)
                }
            } label: {
                Text("Step", bundle: .module)
            }
            HStack {
                TextField(String(localized: "Start (s)", bundle: .module), value: $step.startS, format: .number)
                    .keyboardType(.numberPad)
                TextField(String(localized: "Water target (g)", bundle: .module), value: $step.waterTargetG, format: .number)
                    .keyboardType(.decimalPad)
            }
            TextField(String(localized: "Instruction", bundle: .module), text: $step.instruction)
        }
        .padding(.vertical, Spacing.xs)
    }
}
