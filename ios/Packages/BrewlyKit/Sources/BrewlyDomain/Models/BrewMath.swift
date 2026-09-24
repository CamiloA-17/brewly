import Foundation

/// Cálculos de café comunes para el barista.
public enum BrewMath {
    /// Relación agua/café (p. ej. 250 g / 15 g → 16.67).
    public static func ratio(dose: Decimal, water: Decimal?) -> Decimal? {
        guard let water, dose > 0 else { return nil }
        return rounded(water / dose, scale: 2)
    }

    /// Agua necesaria para una dosis y relación dadas.
    public static func water(forDose dose: Decimal, ratio: Decimal) -> Decimal {
        rounded(dose * ratio, scale: 1)
    }

    /// Dosis necesaria para obtener cierta cantidad de agua con una relación.
    public static func dose(forWater water: Decimal, ratio: Decimal) -> Decimal? {
        guard ratio > 0 else { return nil }
        return rounded(water / ratio, scale: 1)
    }

    /// Porcentaje de extracción: (bebida × TDS%) / dosis.
    public static func extractionYield(beverageG: Decimal, tds: Decimal, dose: Decimal) -> Decimal? {
        guard dose > 0 else { return nil }
        return rounded(beverageG * tds / dose, scale: 1)
    }

    /// Escala una receta a una nueva dosis manteniendo proporciones (pasos incluidos).
    public static func scale(_ recipe: Recipe, toDose newDose: Decimal) -> Recipe {
        guard recipe.doseG > 0, newDose > 0 else { return recipe }
        let factor = newDose / recipe.doseG
        var scaled = recipe
        scaled.doseG = newDose
        scaled.waterG = recipe.waterG.map { rounded($0 * factor, scale: 1) }
        scaled.yieldG = recipe.yieldG.map { rounded($0 * factor, scale: 1) }
        scaled.steps = recipe.steps.map { step in
            var step = step
            step.waterG = step.waterG.map { rounded($0 * factor, scale: 1) }
            return step
        }
        scaled.ratio = ratio(dose: scaled.doseG, water: scaled.waterG)
        return scaled
    }

    public static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }
}
