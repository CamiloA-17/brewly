import BrewlyDomain
import SwiftUI

/// A compact brewing parameter, e.g. "1:16.7" with a drop icon.
public struct ParameterBadge: View {
    private let systemImage: String
    private let value: String

    public init(systemImage: String, value: String) {
        self.systemImage = systemImage
        self.value = value
    }

    public var body: some View {
        Label(value, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color.brewlyCrema, in: Capsule())
            .foregroundStyle(Color.brewlyEspresso)
    }
}

/// A row of the most important parameters of a recipe.
public struct RecipeParametersRow: View {
    private let doseG: Double
    private let ratio: Double
    private let grindSize: GrindSize
    private let waterTempC: Double?
    private let totalTimeS: Int?

    public init(doseG: Double, ratio: Double, grindSize: GrindSize, waterTempC: Double?, totalTimeS: Int?) {
        self.doseG = doseG
        self.ratio = ratio
        self.grindSize = grindSize
        self.waterTempC = waterTempC
        self.totalTimeS = totalTimeS
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ParameterBadge(systemImage: "scalemass", value: BrewFormat.grams(doseG))
                ParameterBadge(systemImage: "drop", value: BrewFormat.ratio(ratio))
                ParameterBadge(systemImage: "circle.grid.3x3", value: grindSize.localizedName)
                if let waterTempC {
                    ParameterBadge(systemImage: "thermometer.medium", value: BrewFormat.temperature(waterTempC))
                }
                if let totalTimeS {
                    ParameterBadge(systemImage: "timer", value: BrewFormat.duration(totalTimeS))
                }
            }
        }
    }
}

/// Read-only or editable 1–5 star rating.
public struct RatingView: View {
    @Binding private var rating: Int?
    private let isEditable: Bool

    public init(rating: Binding<Int?>) {
        _rating = rating
        isEditable = true
    }

    public init(rating: Int?) {
        _rating = .constant(rating)
        isEditable = false
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                    .foregroundStyle(Color.brewlyAccent)
                    .onTapGesture {
                        guard isEditable else { return }
                        rating = rating == value ? nil : value
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(rating ?? 0)/5"))
    }
}

/// The average rating of a recipe's brews, rounded to whole stars, with how many brews it has.
public struct AverageRatingView: View {
    private let rating: Double
    private let count: Int

    public init(rating: Double, count: Int) {
        self.rating = rating
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 4) {
            RatingView(rating: Int(rating.rounded()))
            Text(verbatim: "(\(count))").foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Average rating \(BrewFormat.number(rating, maxFractionDigits: 1)) from \(count) brews", bundle: .module))
    }
}

/// Validation message shown under a form field.
public struct FieldErrorText: View {
    private let message: String?

    public init(_ message: String?) {
        self.message = message
    }

    public var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.brewlyError)
        }
    }
}

/// A searchable list that toggles membership of items in a set (e.g. varietals, flavor notes).
public struct MultiSelectionList<Item: Identifiable>: View where Item.ID == String {
    private let items: [Item]
    private let title: (Item) -> String
    private let subtitle: (Item) -> String?
    @Binding private var selection: Set<String>
    @State private var query = ""

    public init(
        items: [Item],
        selection: Binding<Set<String>>,
        title: @escaping (Item) -> String,
        subtitle: @escaping (Item) -> String? = { _ in nil }
    ) {
        self.items = items
        _selection = selection
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        List(filteredItems) { item in
            Button {
                if selection.contains(item.id) {
                    selection.remove(item.id)
                } else {
                    selection.insert(item.id)
                }
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(title(item)).foregroundStyle(.primary)
                        if let subtitle = subtitle(item) {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selection.contains(item.id) {
                        Image(systemName: "checkmark").foregroundStyle(Color.brewlyAccent)
                    }
                }
            }
        }
        .searchable(text: $query)
    }

    private var filteredItems: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { title($0).localizedCaseInsensitiveContains(trimmed) }
    }
}
