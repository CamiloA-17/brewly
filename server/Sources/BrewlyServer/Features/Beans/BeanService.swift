import BrewlyAPI
import Foundation
import PostgresNIO

/// Business rules for coffee beans.
struct BeanService: Sendable {
    let beans: any BeanRepository

    func list(ownerID: UUID, includeArchived: Bool) async throws -> [BeanDTO] {
        try await beans.list(ownerID: ownerID, includeArchived: includeArchived)
    }

    func get(id: UUID, viewerID: UUID) async throws -> BeanDTO {
        guard let bean = try await beans.find(id: id, viewerID: viewerID) else { throw AppError.notFound("Bean") }
        return bean
    }

    func create(ownerID: UUID, _ request: UpsertBeanRequest) async throws -> BeanDTO {
        let bean = try validated(request)
        return try await mappingReferenceErrors { try await beans.create(ownerID: ownerID, bean) }
    }

    func update(id: UUID, ownerID: UUID, _ request: UpsertBeanRequest) async throws -> BeanDTO {
        let bean = try validated(request)
        let updated = try await mappingReferenceErrors { try await beans.update(id: id, ownerID: ownerID, bean) }
        guard let updated else { throw AppError.notFound("Bean") }
        return updated
    }

    func delete(id: UUID, ownerID: UUID) async throws {
        let deleted: Bool
        do {
            deleted = try await beans.delete(id: id, ownerID: ownerID)
        } catch let error as PSQLError where error.isForeignKeyViolation {
            throw AppError.conflict(
                code: APIErrorCode.beanInUse,
                message: "This bean is used by one or more recipes. Archive it instead."
            )
        }
        guard deleted else { throw AppError.notFound("Bean") }
    }

    /// Validates the request and normalizes blank text to `nil` and duplicated slugs.
    func validated(_ request: UpsertBeanRequest, now: Date = Date()) throws -> UpsertBeanRequest {
        // "Today" is taken one day ahead in UTC so users in any time zone can log today's roast.
        let latestAllowedDay = CalendarDate(date: now.addingTimeInterval(86_400), timeZone: TimeZone(identifier: "UTC")!)
        let violations = BeanRules.validate(request.parameters, today: latestAllowedDay)
        guard violations.isEmpty else { throw AppError.validation(violations) }

        var bean = request
        bean.name = request.name.trimmingWhitespace
        bean.roaster = request.roaster.nilIfBlank
        bean.countryCode = request.countryCode.nilIfBlank?.uppercased()
        bean.region = request.region.nilIfBlank
        bean.farm = request.farm.nilIfBlank
        bean.producer = request.producer.nilIfBlank
        bean.processingMethodSlug = request.processingMethodSlug.nilIfBlank
        bean.notes = request.notes.nilIfBlank
        bean.varietalSlugs = request.varietalSlugs.uniqued
        bean.flavorNoteSlugs = request.flavorNoteSlugs.uniqued
        return bean
    }

    /// Unknown catalog references surface as foreign key violations; report the offending field.
    private func mappingReferenceErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PSQLError where error.isForeignKeyViolation {
            let field = switch error.constraintName {
            case "coffee_beans_country_code_fkey": "countryCode"
            case "coffee_beans_processing_method_slug_fkey": "processingMethodSlug"
            case "bean_varietals_varietal_slug_fkey": "varietalSlugs"
            case "bean_flavor_notes_flavor_note_slug_fkey": "flavorNoteSlugs"
            default: "unknown"
            }
            throw AppError.unknownReference(field: field)
        }
    }
}
