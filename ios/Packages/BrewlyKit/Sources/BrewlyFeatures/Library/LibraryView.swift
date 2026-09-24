import BrewlyDomain
import SwiftUI

/// "Mi barra": el espacio personal (y privado por defecto) del barista.
struct LibraryView: View {
    enum Area: String, CaseIterable, Identifiable {
        case recipes = "Recetas"
        case beans = "Cafés"
        case brews = "Bitácora"
        var id: Self { self }
    }

    @State private var area: Area = .recipes

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Sección", selection: $area) {
                    ForEach(Area.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch area {
                case .recipes: RecipeListView()
                case .beans: BeanListView()
                case .brews: BrewLogView()
                }
            }
            .navigationTitle("Mi barra")
            .brewlyDestinations()
        }
    }
}

/// Catálogos que usan varios formularios (métodos, cafés, equipo).
@MainActor
@Observable
final class LibraryCatalog {
    private(set) var methods: [BrewMethod] = []
    private(set) var beans: [CoffeeBean] = []
    private(set) var equipment: [Equipment] = []

    func load(using coffee: any CoffeeRepository) async {
        async let methods = coffee.brewMethods()
        async let beans = coffee.beans(includeArchived: false)
        async let equipment = coffee.equipment()
        self.methods = (try? await methods) ?? []
        self.beans = (try? await beans) ?? []
        self.equipment = (try? await equipment) ?? []
    }

    func method(id: UUID?) -> BrewMethod? { methods.first { $0.id == id } }
    func bean(id: UUID?) -> CoffeeBean? { beans.first { $0.id == id } }
    var grinders: [Equipment] { equipment.filter { $0.type == .grinder } }
}
