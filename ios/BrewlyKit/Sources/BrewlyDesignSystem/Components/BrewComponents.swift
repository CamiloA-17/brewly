import BrewlyDomain
import SwiftUI

/// A journal entry in a list: bean, method, time, rating and the main parameters.
public struct BrewLogRow: View {
    private let brew: BrewLog
    private let catalog: Catalog

    public init(brew: BrewLog, catalog: Catalog) {
        self.brew = brew
        self.catalog = catalog
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(brew.bean.name).font(.headline)
                Spacer()
                if let rating = brew.tasting.rating {
                    RatingView(rating: rating).font(.caption2)
                }
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.xs) {
                ParameterBadge(systemImage: "scalemass", value: BrewFormat.grams(brew.doseG))
                if let ratio = brew.ratio {
                    ParameterBadge(systemImage: "drop", value: BrewFormat.ratio(ratio))
                }
                if let time = brew.totalTimeS {
                    ParameterBadge(systemImage: "timer", value: BrewFormat.duration(time))
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// "V60 · 8:30 AM · Floral V60"
    private var subtitle: String {
        let method = catalog.brewMethod(brew.methodSlug)?.localizedName ?? brew.methodSlug
        let time = brew.brewedAt.formatted(date: .omitted, time: .shortened)
        return [method, time, brew.recipe?.title].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A 1–5 tasting score as five dots, editable or read-only.
public struct ScoreDots: View {
    @Binding private var score: Int?
    private let isEditable: Bool

    public init(score: Binding<Int?>) {
        _score = score
        isEditable = true
    }

    public init(score: Int?) {
        _score = .constant(score)
        isEditable = false
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { value in
                Circle()
                    .fill(value <= (score ?? 0) ? Color.brewlyAccent : Color.brewlyCrema)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle().inset(by: -4))
                    .onTapGesture {
                        guard isEditable else { return }
                        score = score == value ? nil : value
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: "\(score ?? 0)/5"))
        .accessibilityAdjustableAction { direction in
            guard isEditable else { return }
            switch direction {
            case .increment: score = min((score ?? 0) + 1, 5)
            case .decrement: score = (score ?? 1) > 1 ? (score ?? 1) - 1 : nil
            @unknown default: break
            }
        }
    }
}
