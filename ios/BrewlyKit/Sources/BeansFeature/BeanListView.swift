import BrewlyDesignSystem
import BrewlyDomain
import SwiftUI

/// Root of the Beans tab: the user's coffee shelf.
public struct BeansRootView: View {
    @State private var model: BeanListViewModel
    @State private var isCreating = false

    public init(dependencies: BeansDependencies) {
        _model = State(initialValue: BeanListViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            AsyncContentView(model.state, retry: model.load) { beans in
                if beans.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("No beans yet", bundle: .module)
                        } icon: {
                            Image(systemName: "leaf")
                        }
                    } description: {
                        Text("Add the coffees you are brewing: farm, altitude, varietal and more.", bundle: .module)
                    } actions: {
                        Button {
                            isCreating = true
                        } label: {
                            Text("Add bean", bundle: .module)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(beans) { bean in
                        NavigationLink(value: bean) {
                            BeanRow(bean: bean, catalog: model.catalog)
                        }
                    }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle(Text("My beans", bundle: .module))
            .navigationDestination(for: Bean.self) { bean in
                BeanDetailView(bean: bean, dependencies: model.dependencies)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $model.includeArchived) {
                        Label {
                            Text("Show archived", bundle: .module)
                        } icon: {
                            Image(systemName: "archivebox")
                        }
                    }
                    .toggleStyle(.button)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Label {
                            Text("Add bean", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isCreating) {
                BeanFormView(bean: nil, dependencies: model.dependencies) { _ in
                    Task { await model.load() }
                }
            }
            .task { await model.load() }
            .onChange(of: model.includeArchived) {
                Task { await model.load() }
            }
        }
    }
}

struct BeanRow: View {
    let bean: Bean
    let catalog: Catalog

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(bean.name).font(.headline)
                if bean.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(Color.brewlyAccent)
                }
                if bean.isArchived {
                    Image(systemName: "archivebox").foregroundStyle(.secondary)
                }
            }
            if let origin = originLine {
                Text(origin).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                if let process = catalog.processingMethod(bean.processingMethodSlug) {
                    ParameterBadge(systemImage: "drop.triangle", value: process.localizedName)
                }
                if let roast = bean.roastLevel {
                    ParameterBadge(systemImage: "flame", value: roast.localizedName)
                }
                if let altitude = BrewFormat.altitude(min: bean.altitudeMinM, max: bean.altitudeMaxM) {
                    ParameterBadge(systemImage: "mountain.2", value: altitude)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var originLine: String? {
        let parts = [bean.farm, catalog.country(bean.countryCode)?.localizedName, bean.roaster].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
