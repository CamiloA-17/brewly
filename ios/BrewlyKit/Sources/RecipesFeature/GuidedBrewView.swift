import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Guides a preparation from the recipe plan and records the actual cup afterward.
struct GuidedBrewView: View {
    let recipe: Recipe
    let sessions: any BrewSessionRepository
    let onSaved: @MainActor (BrewSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date?
    @State private var elapsedBeforePause = 0
    @State private var draft: BrewSessionDraft
    @State private var isReviewing = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(recipe: Recipe, sessions: any BrewSessionRepository,
         onSaved: @escaping @MainActor (BrewSession) -> Void) {
        self.recipe = recipe
        self.sessions = sessions
        self.onSaved = onSaved
        _draft = State(initialValue: BrewSessionDraft(recipe: recipe, elapsedS: 0))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = elapsed(at: context.date)
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        Text(recipe.bean.name).font(.title2.bold())
                        HStack {
                            ParameterBadge(systemImage: "scalemass", value: BrewFormat.grams(recipe.doseG))
                            ParameterBadge(systemImage: "drop", value: BrewFormat.ratio(recipe.ratio))
                        }
                        Text(BrewFormat.duration(seconds))
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)

                        if let step = currentStep(at: seconds) {
                            VStack(alignment: .leading, spacing: Spacing.s) {
                                Text("Now", bundle: .module).font(.caption).foregroundStyle(.secondary)
                                Text(step.kind.localizedName).font(.title3.bold())
                                if let target = step.waterTargetG {
                                    Text("Scale target: \(BrewFormat.grams(target))", bundle: .module)
                                }
                                if let instruction = step.instruction { Text(instruction) }
                                if let next = nextStep(after: seconds) {
                                    Text("Next at \(BrewFormat.duration(next.startS))", bundle: .module)
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brewlyAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        }

                        HStack {
                            Button(startedAt == nil ? String(localized: "Start or resume", bundle: .module)
                                  : String(localized: "Pause", bundle: .module)) {
                                if let startedAt {
                                    elapsedBeforePause += max(0, Int(Date.now.timeIntervalSince(startedAt)))
                                    self.startedAt = nil
                                } else {
                                    startedAt = .now
                                }
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button { finish(at: context.date) } label: {
                                Text("Finish brew", bundle: .module)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if recipe.steps.isEmpty {
                            Text("This recipe has no timed steps. Use the timer and record your result.", bundle: .module)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(Text("Prepare coffee", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Close", bundle: .module) }
                }
            }
            .sheet(isPresented: $isReviewing) { reviewSheet }
        }
    }

    private func elapsed(at date: Date) -> Int {
        elapsedBeforePause + (startedAt.map { max(0, Int(date.timeIntervalSince($0))) } ?? 0)
    }

    private func currentStep(at seconds: Int) -> RecipeStep? {
        recipe.steps.last { $0.startS <= seconds } ?? recipe.steps.first
    }

    private func nextStep(after seconds: Int) -> RecipeStep? {
        recipe.steps.first { $0.startS > seconds }
    }

    private func finish(at date: Date) {
        draft.elapsedS = elapsed(at: date)
        startedAt = nil
        elapsedBeforePause = draft.elapsedS
        isReviewing = true
    }

    private var reviewSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Dose (g)", bundle: .module), value: $draft.doseG, format: .number)
                    TextField(String(localized: "Water (g)", bundle: .module), value: $draft.waterG, format: .number)
                    TextField(String(localized: "Beverage (g)", bundle: .module), value: $draft.yieldG, format: .number)
                    TextField(String(localized: "TDS (%)", bundle: .module), value: $draft.tdsPercent, format: .number)
                    TextField(String(localized: "Grind setting", bundle: .module), text: Binding(
                        get: { draft.grindSetting ?? "" }, set: { draft.grindSetting = $0.isEmpty ? nil : $0 }
                    ))
                } header: { Text("Actual preparation", bundle: .module) }
                Section {
                    score(String(localized: "Overall", bundle: .module), value: $draft.rating)
                    score(String(localized: "Acidity", bundle: .module), value: $draft.acidity)
                    score(String(localized: "Bitterness", bundle: .module), value: $draft.bitterness)
                    score(String(localized: "Body", bundle: .module), value: $draft.body)
                    TextField(String(localized: "Tasting notes", bundle: .module), text: Binding(
                        get: { draft.notes ?? "" }, set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                } header: { Text("How did it taste?", bundle: .module) }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(Text("Record this cup", bundle: .module))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { isReviewing = false } label: { Text("Back", bundle: .module) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: { Text("Save cup", bundle: .module) }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func score(_ title: String, value: Binding<Int?>) -> some View {
        Picker(title, selection: value) {
            Text("Not rated", bundle: .module).tag(Int?.none)
            ForEach(1...5, id: \.self) { number in
                Text("\(number)").tag(Optional(number))
            }
        }
    }

    private func save() async {
        if let first = BrewSessionRules.validate(draft.parameters).first {
            errorMessage = first.localizedMessage
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await sessions.create(draft)
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
