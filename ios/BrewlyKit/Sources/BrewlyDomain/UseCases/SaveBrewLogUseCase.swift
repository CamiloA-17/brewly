import Foundation

/// Validates a journal entry against its brew method and saves it.
public struct SaveBrewLogUseCase: Sendable {
    private let brews: any BrewLogRepository

    public init(brews: any BrewLogRepository) {
        self.brews = brews
    }

    /// Every broken rule of the draft; empty when it can be saved.
    public static func violations(for draft: BrewLogDraft, method: BrewMethod?, now: Date = Date()) -> [RuleViolation] {
        var violations: [RuleViolation] = []
        if draft.beanID == nil { violations.append(RuleViolation(field: "beanId", kind: .required)) }
        if method == nil { violations.append(RuleViolation(field: "methodSlug", kind: .required)) }
        guard let doseG = draft.doseG else {
            violations.append(RuleViolation(field: "doseG", kind: .required))
            return violations
        }
        guard let method else { return violations }
        let parameters = BrewParameters(
            brewedAt: draft.brewedAt, doseG: doseG, waterG: draft.waterG, yieldG: draft.yieldG,
            grindSetting: draft.grindSetting, waterTempC: draft.waterTempC, totalTimeS: draft.totalTimeS,
            rating: draft.tasting.rating, acidity: draft.tasting.acidity, sweetness: draft.tasting.sweetness,
            body: draft.tasting.body, bitterness: draft.tasting.bitterness, aftertaste: draft.tasting.aftertaste,
            tdsPercent: draft.tdsPercent, notes: draft.notes
        )
        return violations + BrewRules.validate(parameters, ratioBasis: method.ratioBasis, now: now)
    }

    /// Creates the brew, or updates it when `id` is given.
    public func callAsFunction(_ draft: BrewLogDraft, method: BrewMethod?, id: UUID? = nil) async throws -> BrewLog {
        let violations = Self.violations(for: draft, method: method)
        guard violations.isEmpty, let beanID = draft.beanID, let method else {
            throw DomainError.validation(violations)
        }
        return try await brews.save(draft, beanID: beanID, methodSlug: method.slug, id: id)
    }
}
