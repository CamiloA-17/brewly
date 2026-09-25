import Foundation

/// Validates a bean draft and saves it.
public struct SaveBeanUseCase: Sendable {
    private let beans: any BeanRepository

    public init(beans: any BeanRepository) {
        self.beans = beans
    }

    public static func violations(for draft: BeanDraft, today: CalendarDate = .today()) -> [RuleViolation] {
        BeanRules.validate(draft.parameters, today: today)
    }

    /// Creates the bean, or updates it when `id` is given.
    public func callAsFunction(_ draft: BeanDraft, id: UUID? = nil) async throws -> Bean {
        let violations = Self.violations(for: draft)
        guard violations.isEmpty else { throw DomainError.validation(violations) }
        if let id {
            return try await beans.update(id: id, draft)
        }
        return try await beans.create(draft)
    }
}
