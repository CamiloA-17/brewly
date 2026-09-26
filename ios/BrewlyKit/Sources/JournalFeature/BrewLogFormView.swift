import BrewlyDesignSystem
import BrewlyDomain
import PhotosUI
import SwiftUI

/// Logs a brew, or edits one. When it follows a recipe, the recipe's parameters come pre-filled.
///
/// It has no navigation stack of its own: it is pushed from a recipe (`AppRoute.newBrew`) or
/// presented in a sheet that wraps it in one.
public struct BrewLogFormView: View {
    @State private var model: BrewLogFormViewModel
    @State private var pickedPhoto: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    private let onSaved: @MainActor (BrewLog) -> Void

    public init(
        brewLog: BrewLog?,
        recipeID: UUID? = nil,
        dependencies: JournalDependencies,
        onSaved: @escaping @MainActor (BrewLog) -> Void = { _ in }
    ) {
        _model = State(initialValue: BrewLogFormViewModel(brewLog: brewLog, recipeID: recipeID, dependencies: dependencies))
        self.onSaved = onSaved
    }

    public var body: some View {
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
                    Text("Every brew uses one of your beans. Add it in the Beans tab.", bundle: .module)
                }
            } else {
                form
            }
        }
        .navigationTitle(model.isEditing ? Text("Edit brew", bundle: .module) : Text("Log a brew", bundle: .module))
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
                            if let brew = await model.save() {
                                onSaved(brew)
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
        .onChange(of: pickedPhoto) {
            guard let item = pickedPhoto else { return }
            Task {
                model.draft.newPhotoData = try? await item.loadTransferable(type: Data.self)
            }
        }
        .task { await model.load() }
    }

    private var form: some View {
        Form {
            brewSection
            dosingSection
            grindSection
            tastingSection
            notesSection
        }
    }

    private var brewSection: some View {
        Section {
            if let recipeTitle = model.draft.recipeTitle {
                LabeledContent {
                    Text(recipeTitle)
                } label: {
                    Text("Recipe", bundle: .module)
                }
            }
            Picker(selection: $model.draft.beanID) {
                ForEach(model.beans) { bean in
                    Text(beanLabel(bean)).tag(Optional(bean.id))
                }
            } label: {
                Text("Bean", bundle: .module)
            }
            FieldErrorText(model.message(for: "beanId"))
            Picker(selection: methodSelection) {
                Text("Choose a method", bundle: .module).tag(String?.none)
                ForEach(model.catalog.brewMethods) { method in
                    Text(method.localizedName).tag(Optional(method.slug))
                }
            } label: {
                Text("Method", bundle: .module)
            }
            FieldErrorText(model.message(for: "methodSlug"))
            DatePicker(selection: $model.draft.brewedAt, in: ...Date()) {
                Text("Brewed", bundle: .module)
            }
            FieldErrorText(model.message(for: "brewedAt"))
        }
    }

    private var dosingSection: some View {
        Section {
            numberField("Dose (g)", value: $model.draft.doseG, field: "doseG")
            if model.ratioBasis == .water {
                numberField("Brew water (g)", value: $model.draft.waterG, field: "waterG")
            }
            numberField("Beverage (g)", value: $model.draft.yieldG, field: "yieldG")
            LabeledContent {
                Text(model.draft.ratio.map(BrewFormat.ratio) ?? "—")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(Color.brewlyAccent)
            } label: {
                Text("Ratio", bundle: .module)
            }
            FieldErrorText(model.message(for: "ratio"))
            numberField("Water temperature (°C)", value: $model.draft.waterTempC, field: "waterTempC")
            integerField("Total time (s)", value: $model.draft.totalTimeS, field: "totalTimeS")
        } header: {
            Text("Parameters", bundle: .module)
        }
    }

    private var grindSection: some View {
        Section {
            if !model.grinders.isEmpty {
                Picker(selection: grinderSelection) {
                    Text("Not specified", bundle: .module).tag(UUID?.none)
                    ForEach(model.grinders) { grinder in
                        Text(grinder.displayName(in: model.catalog)).tag(Optional(grinder.id))
                    }
                } label: {
                    Text("Grinder", bundle: .module)
                }
            }
            Picker(selection: $model.draft.grindSize) {
                Text("Not specified", bundle: .module).tag(GrindSize?.none)
                ForEach(GrindSize.allCases, id: \.self) { size in
                    Text(size.localizedName).tag(Optional(size))
                }
            } label: {
                Text("Grind size", bundle: .module)
            }
            TextField(String(localized: "Grinder setting (e.g. 24 clicks)", bundle: .module), text: $model.draft.grindSetting)
            FieldErrorText(model.message(for: "grindSetting"))
        } header: {
            Text("Grind", bundle: .module)
        }
    }

    private var tastingSection: some View {
        Section {
            LabeledContent {
                RatingView(rating: $model.draft.tasting.rating)
            } label: {
                Text("Rating", bundle: .module)
            }
            ForEach(Tasting.Attribute.allCases, id: \.self) { attribute in
                LabeledContent(attribute.localizedName) {
                    ScoreDots(score: $model.draft.tasting[attribute])
                }
            }
            numberField("TDS (%)", value: $model.draft.tdsPercent, field: "tdsPercent")
            LabeledContent {
                Text(model.draft.extractionYield.map(BrewFormat.percent) ?? "—")
                    .monospacedDigit()
            } label: {
                Text("Extraction yield", bundle: .module)
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
                    Text(model.draft.flavorNoteSlugs.compactMap { model.catalog.flavorNote($0)?.localizedName }
                        .sorted().joined(separator: ", "))
                } label: {
                    Text("Tasting notes", bundle: .module)
                }
            }
        } header: {
            Text("Tasting", bundle: .module)
        } footer: {
            Text("Tap a dot to score from 1 to 5; tap it again to clear it.", bundle: .module)
        }
    }

    private var notesSection: some View {
        Section {
            TextField(String(localized: "How did it taste? What would you change?", bundle: .module), text: $model.draft.notes, axis: .vertical)
                .lineLimit(2...6)
            FieldErrorText(model.message(for: "notes"))
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Label {
                    hasPhoto ? Text("Change photo", bundle: .module) : Text("Add a photo", bundle: .module)
                } icon: {
                    Image(systemName: "camera")
                }
            }
            if hasPhoto {
                Button(role: .destructive) {
                    model.draft.newPhotoData = nil
                    model.draft.photoURL = nil
                    pickedPhoto = nil
                } label: {
                    Text("Remove photo", bundle: .module)
                }
            }
            FieldErrorText(model.message(for: "photoMediaId") ?? model.message(for: "photos"))
            Picker(selection: $model.draft.visibility) {
                Text("Only me", bundle: .module).tag(Visibility.private)
                Text("Followers", bundle: .module).tag(Visibility.followers)
                Text("Everyone", bundle: .module).tag(Visibility.public)
            } label: {
                Text("Who can see it", bundle: .module)
            }
            FieldErrorText(model.errorMessage)
        } header: {
            Text("Notes", bundle: .module)
        }
    }

    // MARK: Inputs

    private var hasPhoto: Bool {
        model.draft.newPhotoData != nil || model.draft.photoURL != nil
    }

    /// "Geisha Washed · 220 g left"
    private func beanLabel(_ bean: Bean) -> String {
        guard let remaining = bean.remainingG else { return bean.name }
        return String(localized: "\(bean.name) · \(BrewFormat.grams(remaining)) left", bundle: .module)
    }

    private var methodSelection: Binding<String?> {
        Binding {
            model.draft.methodSlug
        } set: { slug in
            model.selectMethod(slug)
        }
    }

    private var grinderSelection: Binding<UUID?> {
        Binding {
            model.draft.equipmentID
        } set: { id in
            model.selectGrinder(id)
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
