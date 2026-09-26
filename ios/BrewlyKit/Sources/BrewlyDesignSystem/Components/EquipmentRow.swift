import BrewlyDomain
import SwiftUI

/// An item of gear in a list: icon, name, kind and its usual grind settings.
public struct EquipmentRow: View {
    private let equipment: Equipment
    private let catalog: Catalog

    public init(equipment: Equipment, catalog: Catalog) {
        self.equipment = equipment
        self.catalog = catalog
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: equipment.kind.systemImage)
                .foregroundStyle(Color.brewlyAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(equipment.displayName(in: catalog)).font(.headline)
                    if equipment.isDefault {
                        Text("Default", bundle: .module)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brewlyCrema, in: Capsule())
                            .foregroundStyle(Color.brewlyEspresso)
                    }
                }
                Text(equipment.kind.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(settings) { setting in
                    Text(verbatim: "\(setting.method): \(setting.value)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private struct Setting: Identifiable {
        var id: String
        var method: String
        var value: String
    }

    /// Settings in the catalog's method order, with localized method names.
    private var settings: [Setting] {
        catalog.brewMethods.compactMap { method in
            equipment.grindSettings[method.slug].map { Setting(id: method.slug, method: method.localizedName, value: $0) }
        }
    }
}
