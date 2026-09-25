import Foundation

/// Brewing calculations. They mirror the generated columns in the `recipes` table.
public enum BrewMath {
    /// Brew ratio (the `N` in `1:N`), rounded to two decimals.
    ///
    /// Uses the brew water when present (filter methods), otherwise the beverage weight
    /// (espresso) — exactly like the `recipes.ratio` generated column.
    public static func ratio(doseG: Double, waterG: Double?, yieldG: Double?) -> Double? {
        guard doseG > 0, let liquid = waterG ?? yieldG else { return nil }
        return rounded(liquid / doseG, places: 2)
    }

    /// Extraction yield percentage: beverage weight × TDS% / dose, rounded to two decimals.
    public static func extractionYield(doseG: Double, beverageG: Double?, tdsPercent: Double?) -> Double? {
        guard doseG > 0, let beverageG, let tdsPercent else { return nil }
        return rounded(beverageG * tdsPercent / doseG, places: 2)
    }

    /// Liquid needed to reach `ratio` with `doseG` of coffee (used to prefill forms).
    public static func liquid(forDoseG doseG: Double, ratio: Double) -> Double {
        rounded(doseG * ratio, places: 1)
    }

    public static func rounded(_ value: Double, places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (value * factor).rounded(.toNearestOrAwayFromZero) / factor
    }
}
