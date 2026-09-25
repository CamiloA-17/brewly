import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

struct BeanDetailView: View {
    @State private var bean: Bean
    @State private var catalog: Catalog = .empty
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let dependencies: BeansDependencies

    init(bean: Bean, dependencies: BeansDependencies) {
        _bean = State(initialValue: bean)
        self.dependencies = dependencies
    }

    var body: some View {
        List {
            Section {
                row("Roaster", bean.roaster)
                row("Country", catalog.country(bean.countryCode)?.localizedName)
                row("Region", bean.region)
                row("Farm", bean.farm)
                row("Producer", bean.producer)
                row("Altitude", BrewFormat.altitude(min: bean.altitudeMinM, max: bean.altitudeMaxM))
            } header: {
                Text("Origin", bundle: .module)
            }

            Section {
                row("Varietals", bean.varietalSlugs.compactMap { catalog.varietal($0)?.name }.joined(separator: ", "))
                row("Process", catalog.processingMethod(bean.processingMethodSlug)?.localizedName)
                row("Harvest", bean.harvestYear.map { String($0) })
                row("SCA score", bean.scaScore.map { BrewFormat.number($0, maxFractionDigits: 2) })
                if bean.isDecaf {
                    Label {
                        Text("Decaf", bundle: .module)
                    } icon: {
                        Image(systemName: "moon.zzz")
                    }
                }
            } header: {
                Text("Coffee", bundle: .module)
            }

            Section {
                row("Roast level", bean.roastLevel?.localizedName)
                row("Roast date", bean.roastDate?.date().formatted(date: .abbreviated, time: .omitted))
                if let days = bean.daysSinceRoast() {
                    LabeledContent {
                        Text(verbatim: "\(days)")
                    } label: {
                        Text("Days since roast", bundle: .module)
                    }
                }
                row("Weight", bean.weightG.map { BrewFormat.grams(Double($0)) })
            } header: {
                Text("Roast", bundle: .module)
            }

            if !bean.flavorNoteSlugs.isEmpty || bean.notes != nil {
                Section {
                    if !bean.flavorNoteSlugs.isEmpty {
                        Text(bean.flavorNoteSlugs.compactMap { catalog.flavorNote($0)?.localizedName }.joined(separator: " · "))
                    }
                    if let notes = bean.notes {
                        Text(notes)
                    }
                } header: {
                    Text("Tasting notes", bundle: .module)
                }
            }

            Section {
                Button {
                    Task { await setArchived(!bean.isArchived) }
                } label: {
                    if bean.isArchived {
                        Text("Move back to my shelf", bundle: .module)
                    } else {
                        Text("Archive (bag finished)", bundle: .module)
                    }
                }
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text("Delete bean", bundle: .module)
                }
                FieldErrorText(errorMessage)
            }
        }
        .navigationTitle(bean.name)
        .toolbar {
            Button {
                isEditing = true
            } label: {
                Text("Edit", bundle: .module)
            }
        }
        .sheet(isPresented: $isEditing) {
            BeanFormView(bean: bean, dependencies: dependencies) { updated in
                bean = updated
            }
        }
        .confirmationDialog(
            Text("Delete this bean?", bundle: .module),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await delete() }
            } label: {
                Text("Delete bean", bundle: .module)
            }
        }
        .task {
            catalog = (try? await dependencies.catalog.catalog()) ?? .empty
        }
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent {
                Text(value)
            } label: {
                Text(title, bundle: .module)
            }
        }
    }

    private func setArchived(_ archived: Bool) async {
        var draft = BeanDraft(bean: bean)
        draft.isArchived = archived
        do {
            bean = try await dependencies.saveBean(draft, id: bean.id)
            errorMessage = nil
        } catch {
            errorMessage = error.brewlyMessage
        }
    }

    private func delete() async {
        do {
            try await dependencies.beans.delete(id: bean.id)
            dismiss()
        } catch {
            errorMessage = error.brewlyMessage
        }
    }
}
