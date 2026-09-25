import Foundation

/// Validates a recipe draft against its brew method and saves it.
public struct SaveRecipeUseCase: Sendable {
    private let recipes: any RecipeRepository

    public init(recipes: any RecipeRepository) {
        self.recipes = recipes
    }

    /// Every broken rule of the draft; empty when it can be saved.
    public static func violations(for draft: RecipeDraft, method: BrewMethod?) -> [RuleViolation] {
        var violations: [RuleViolation] = []
        if draft.beanID == nil { violations.append(RuleViolation(field: "beanId", kind: .required)) }
        if method == nil { violations.append(RuleViolation(field: "methodSlug", kind: .required)) }
        guard let doseG = draft.doseG else {
            violations.append(RuleViolation(field: "doseG", kind: .required))
            return violations
        }
        guard let method else { return violations }
        return violations + RecipeRules.validate(parameters(for: draft, doseG: doseG), ratioBasis: method.ratioBasis)
    }

    /// Creates the recipe, or updates it when `id` is given.
    public func callAsFunction(_ draft: RecipeDraft, method: BrewMethod?, id: UUID? = nil) async throws -> Recipe {
        let violations = Self.violations(for: draft, method: method)
        guard violations.isEmpty, let beanID = draft.beanID, let method else {
            throw DomainError.validation(violations)
        }
        let input = RecipeInput(beanID: beanID, methodSlug: method.slug, draft: draft)
        if let id {
            return try await recipes.update(id: id, input)
        }
        return try await recipes.create(input)
    }

    private static func parameters(for draft: RecipeDraft, doseG: Double) -> RecipeParameters {
        RecipeParameters(
            title: draft.title,
            description: draft.description,
            doseG: doseG,
            waterG: draft.waterG,
            yieldG: draft.yieldG,
            grindSetting: draft.grindSetting,
            grindMicrons: draft.grindMicrons,
            waterTempC: draft.waterTempC,
            bloomWaterG: draft.bloomWaterG,
            bloomTimeS: draft.bloomTimeS,
            totalTimeS: draft.totalTimeS,
            pressureBar: draft.pressureBar,
            waterProfile: draft.waterProfile,
            waterTdsPpm: draft.waterTdsPpm,
            tdsPercent: draft.tdsPercent,
            rating: draft.rating,
            notes: draft.notes,
            steps: draft.steps.map {
                RecipeParameters.Step(startS: $0.startS, waterTargetG: $0.waterTargetG, instruction: $0.instruction)
            }
        )
    }
}
