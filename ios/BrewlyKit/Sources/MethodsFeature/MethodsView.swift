import BrewlyDesignSystem
import BrewlyDomain
import Observation
import SwiftUI

public struct MethodsDependencies: Sendable {
    public var catalog: any CatalogRepository
    public var userMethods: any UserMethodsRepository

    public init(catalog: any CatalogRepository, userMethods: any UserMethodsRepository) {
        self.catalog = catalog
        self.userMethods = userMethods
    }
}

@MainActor
@Observable
final class MethodsViewModel {
    private(set) var state: LoadState<[BrewMethod]> = .idle
    private(set) var myMethods: Set<String> = []
    private(set) var errorMessage: String?
    private let dependencies: MethodsDependencies

    init(dependencies: MethodsDependencies) {
        self.dependencies = dependencies
    }

    struct Section: Identifiable {
        let category: MethodCategory
        let methods: [BrewMethod]
        var id: MethodCategory { category }
    }

    /// Methods grouped by category, in catalog order.
    var sections: [Section] {
        let methods = state.value ?? []
        return MethodCategory.allCases.compactMap { category in
            let inCategory = methods.filter { $0.category == category }
            return inCategory.isEmpty ? nil : Section(category: category, methods: inCategory)
        }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let catalog = dependencies.catalog.catalog()
            async let mine = dependencies.userMethods.myMethodSlugs()
            let (loadedCatalog, loadedMine) = try await (catalog, mine)
            myMethods = loadedMine
            state = .loaded(loadedCatalog.brewMethods)
        } catch {
            state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
        }
    }

    func isUsing(_ method: BrewMethod) -> Bool {
        myMethods.contains(method.slug)
    }

    /// Optimistically toggles the method and reverts if the request fails.
    func toggle(_ method: BrewMethod) async {
        let isUsing = !myMethods.contains(method.slug)
        if isUsing { myMethods.insert(method.slug) } else { myMethods.remove(method.slug) }
        do {
            try await dependencies.userMethods.setUsing(isUsing, methodSlug: method.slug)
            errorMessage = nil
        } catch {
            if isUsing { myMethods.remove(method.slug) } else { myMethods.insert(method.slug) }
            errorMessage = error.brewlyMessage
        }
    }
}

/// The global catalog of brew methods; users mark the ones they use.
public struct MethodsView: View {
    @State private var model: MethodsViewModel

    public init(dependencies: MethodsDependencies) {
        _model = State(initialValue: MethodsViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            AsyncContentView(model.state, retry: model.load) { _ in
                List {
                    Section {
                        Text("Mark the methods you use. They appear first when you create a recipe.", bundle: .module)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        FieldErrorText(model.errorMessage)
                    }
                    ForEach(model.sections) { section in
                        Section {
                            ForEach(section.methods) { method in
                                MethodRow(method: method, isUsing: model.isUsing(method)) {
                                    Task { await model.toggle(method) }
                                }
                            }
                        } header: {
                            Text(section.category.localizedName)
                        }
                    }
                }
                .refreshable { await model.load() }
            }
            .navigationTitle(Text("Brew methods", bundle: .module))
            .task { await model.load() }
        }
    }
}

private struct MethodRow: View {
    let method: BrewMethod
    let isUsing: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(method.localizedName).font(.headline)
                if let description = method.description {
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: Spacing.xs) {
                    if let ratio = method.defaultRatio {
                        ParameterBadge(systemImage: "drop", value: BrewFormat.ratio(ratio))
                    }
                    if let grind = method.defaultGrindSize {
                        ParameterBadge(systemImage: "circle.grid.3x3", value: grind.localizedName)
                    }
                    if let temperature = method.defaultWaterTempC {
                        ParameterBadge(systemImage: "thermometer.medium", value: BrewFormat.temperature(temperature))
                    }
                }
            }
            Spacer()
            Button(action: toggle) {
                Image(systemName: isUsing ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isUsing ? Color.brewlyAccent : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("I use it", bundle: .module))
            .accessibilityAddTraits(isUsing ? .isSelected : [])
        }
        .padding(.vertical, Spacing.xs)
    }
}
