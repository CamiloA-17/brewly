import BrewlyDomain
import SwiftUI
import UIKit

/// Temporizador guiado: recorre los pasos de la receta y al terminar
/// permite registrar la preparación en la bitácora.
struct BrewTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    let recipe: Recipe

    @State private var startDate: Date?
    @State private var pausedElapsed: TimeInterval = 0
    @State private var logging: Brew?

    private func elapsed(at now: Date) -> Int {
        let running = startDate.map { now.timeIntervalSince($0) } ?? 0
        return Int(pausedElapsed + running)
    }

    private func currentStepIndex(at seconds: Int) -> Int? {
        recipe.steps.lastIndex { ($0.startAtS ?? 0) <= seconds }
    }

    /// Agua acumulada que debería haber en la báscula en este momento.
    private func targetWater(upTo index: Int?) -> Decimal {
        guard let index else { return 0 }
        return recipe.steps[...index].reduce(0) { $0 + ($1.waterG ?? 0) }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let seconds = elapsed(at: context.date)
                let index = currentStepIndex(at: seconds)

                VStack(spacing: 24) {
                    Text(Format.duration(seconds))
                        .font(.system(size: 72, weight: .semibold, design: .rounded).monospacedDigit())

                    Label("Báscula: \(Format.grams(targetWater(upTo: index)))", systemImage: "scalemass")
                        .font(.title3)
                        .foregroundStyle(BrewlyTheme.crema)

                    if let index {
                        let step = recipe.steps[index]
                        VStack(spacing: 8) {
                            Text(step.kind.title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                            Text(step.instruction).font(.title2).multilineTextAlignment(.center)
                        }
                        .brewlyCard()

                        if index + 1 < recipe.steps.count {
                            let next = recipe.steps[index + 1]
                            Text("Siguiente en \(Format.duration(max(0, (next.startAtS ?? 0) - seconds))): \(next.instruction)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button(startDate == nil ? "Iniciar" : "Pausar") {
                            if let start = startDate {
                                pausedElapsed += Date.now.timeIntervalSince(start)
                                startDate = nil
                            } else {
                                startDate = .now
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Terminar") {
                            guard let owner = session.currentUserID else { return }
                            startDate = nil
                            pausedElapsed = TimeInterval(seconds)
                            logging = Brew(from: recipe, ownerID: owner, elapsed: max(seconds, 1))
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .sheet(item: $logging) { brew in
                BrewEditorView(brew: brew) { _ in dismiss() }
            }
        }
        // Mantiene la pantalla encendida mientras se prepara.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
