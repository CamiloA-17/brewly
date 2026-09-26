import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

protocol BeanRepository: Sendable {
    func list(ownerID: UUID, includeArchived: Bool) async throws -> [BeanDTO]
    /// The bean if `viewerID` is allowed to see it.
    func find(id: UUID, viewerID: UUID) async throws -> BeanDTO?
    func create(ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO
    /// `nil` when the bean does not exist or is not owned by `ownerID`.
    func update(id: UUID, ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO?
    /// `false` when the bean does not exist or is not owned by `ownerID`.
    func delete(id: UUID, ownerID: UUID) async throws -> Bool
}

struct PostgresBeanRepository: BeanRepository {
    let database: any Database

    private struct BeanRow: Decodable {
        var id: UUID
        var ownerId: UUID
        var name: String
        var roaster: String?
        var countryCode: String?
        var region: String?
        var farm: String?
        var producer: String?
        var altitudeMinM: Int?
        var altitudeMaxM: Int?
        var processingMethodSlug: String?
        var varietalSlugs: [String]
        var flavorNoteSlugs: [String]
        var roastLevel: String?
        var roastDate: String?
        var harvestYear: Int?
        var scaScore: Double?
        var weightG: Int?
        var remainingG: Double?
        var isDecaf: Bool
        var notes: String?
        var photoUrl: String?
        var visibility: String
        var isArchived: Bool
        var createdAt: Date
        var updatedAt: Date

        var dto: BeanDTO {
            BeanDTO(
                id: id,
                ownerId: ownerId,
                name: name,
                roaster: roaster,
                countryCode: countryCode,
                region: region,
                farm: farm,
                producer: producer,
                altitudeMinM: altitudeMinM,
                altitudeMaxM: altitudeMaxM,
                processingMethodSlug: processingMethodSlug,
                varietalSlugs: varietalSlugs,
                flavorNoteSlugs: flavorNoteSlugs,
                roastLevel: roastLevel.flatMap(RoastLevel.init(rawValue:)),
                roastDate: roastDate.flatMap(CalendarDate.init(isoString:)),
                harvestYear: harvestYear,
                scaScore: scaScore,
                weightG: weightG,
                remainingG: remainingG,
                isDecaf: isDecaf,
                notes: notes,
                photoURL: photoUrl,
                visibility: Visibility(rawValue: visibility) ?? .private,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private static let select = """
        SELECT b.id, b.owner_id, b.name, b.roaster, b.country_code::text AS country_code, b.region, b.farm,
               b.producer, b.altitude_min_m, b.altitude_max_m, b.processing_method_slug,
               coalesce((SELECT array_agg(v.varietal_slug ORDER BY v.varietal_slug)
                         FROM bean_varietals v WHERE v.bean_id = b.id), '{}') AS varietal_slugs,
               coalesce((SELECT array_agg(f.flavor_note_slug ORDER BY f.flavor_note_slug)
                         FROM bean_flavor_notes f WHERE f.bean_id = b.id), '{}') AS flavor_note_slugs,
               b.roast_level::text AS roast_level, to_char(b.roast_date, 'YYYY-MM-DD') AS roast_date,
               b.harvest_year, b.sca_score::float8 AS sca_score, b.weight_g,
               b.remaining_g::float8 AS remaining_g, b.is_decaf, b.notes, b.photo_url,
               b.visibility::text AS visibility, b.archived_at IS NOT NULL AS is_archived,
               b.created_at, b.updated_at
        FROM coffee_beans b
        """

    func list(ownerID: UUID, includeArchived: Bool) async throws -> [BeanDTO] {
        try await database.sql.raw("""
            \(unsafeRaw: Self.select)
            WHERE b.owner_id = \(bind: ownerID) AND (\(bind: includeArchived) OR b.archived_at IS NULL)
            ORDER BY b.archived_at IS NOT NULL, b.created_at DESC, b.id DESC
            """).all().map { try $0.decodeSnakeCase(BeanRow.self).dto }
    }

    func find(id: UUID, viewerID: UUID) async throws -> BeanDTO? {
        try await Self.find(id: id, viewerID: viewerID, sql: database.sql)
    }

    private static func find(id: UUID, viewerID: UUID, sql: any SQLDatabase) async throws -> BeanDTO? {
        try await sql.raw("""
            \(unsafeRaw: Self.select)
            WHERE b.id = \(bind: id) AND can_view_content(\(bind: viewerID), b.owner_id, b.visibility)
            """).first().map { try $0.decodeSnakeCase(BeanRow.self).dto }
    }

    func create(ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO {
        try await database.transaction { tx in
            let sql = tx.sql
            guard let row = try await sql.raw("""
                INSERT INTO coffee_beans
                    (owner_id, name, roaster, country_code, region, farm, producer, altitude_min_m, altitude_max_m,
                     processing_method_slug, roast_level, roast_date, harvest_year, sca_score, weight_g, remaining_g,
                     is_decaf, notes, visibility, archived_at)
                VALUES
                    (\(bind: ownerID), \(bind: bean.name), \(bind: bean.roaster), \(bind: bean.countryCode),
                     \(bind: bean.region), \(bind: bean.farm), \(bind: bean.producer), \(bind: bean.altitudeMinM),
                     \(bind: bean.altitudeMaxM), \(bind: bean.processingMethodSlug), \(bind: bean.roastLevel?.rawValue),
                     \(bind: bean.roastDate?.isoString)::date, \(bind: bean.harvestYear), \(bind: bean.scaScore),
                     \(bind: bean.weightG), coalesce(\(bind: bean.remainingG)::numeric, \(bind: bean.weightG)::numeric),
                     \(bind: bean.isDecaf), \(bind: bean.notes), \(bind: bean.visibility.rawValue),
                     CASE WHEN \(bind: bean.isArchived) THEN now() END)
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: "internal_error", message: "Bean was not created.") }
            let id = try row.decode(column: "id", as: UUID.self)
            try await Self.replaceRelations(beanID: id, bean, sql: sql)
            guard let created = try await Self.find(id: id, viewerID: ownerID, sql: sql) else {
                throw AppError.notFound("Bean")
            }
            return created
        }
    }

    func update(id: UUID, ownerID: UUID, _ bean: UpsertBeanRequest) async throws -> BeanDTO? {
        try await database.transaction { tx in
            let sql = tx.sql
            let row = try await sql.raw("""
                UPDATE coffee_beans SET
                    name = \(bind: bean.name), roaster = \(bind: bean.roaster), country_code = \(bind: bean.countryCode),
                    region = \(bind: bean.region), farm = \(bind: bean.farm), producer = \(bind: bean.producer),
                    altitude_min_m = \(bind: bean.altitudeMinM), altitude_max_m = \(bind: bean.altitudeMaxM),
                    processing_method_slug = \(bind: bean.processingMethodSlug),
                    roast_level = \(bind: bean.roastLevel?.rawValue),
                    roast_date = \(bind: bean.roastDate?.isoString)::date, harvest_year = \(bind: bean.harvestYear),
                    sca_score = \(bind: bean.scaScore), weight_g = \(bind: bean.weightG),
                    remaining_g = \(bind: bean.remainingG), is_decaf = \(bind: bean.isDecaf),
                    notes = \(bind: bean.notes), visibility = \(bind: bean.visibility.rawValue),
                    archived_at = CASE WHEN \(bind: bean.isArchived) THEN coalesce(archived_at, now()) END
                WHERE id = \(bind: id) AND owner_id = \(bind: ownerID)
                RETURNING id
                """).first()
            guard row != nil else { return nil }
            try await Self.replaceRelations(beanID: id, bean, sql: sql)
            return try await Self.find(id: id, viewerID: ownerID, sql: sql)
        }
    }

    func delete(id: UUID, ownerID: UUID) async throws -> Bool {
        try await database.sql.raw("""
            DELETE FROM coffee_beans WHERE id = \(bind: id) AND owner_id = \(bind: ownerID) RETURNING id
            """).first() != nil
    }

    private static func replaceRelations(beanID: UUID, _ bean: UpsertBeanRequest, sql: any SQLDatabase) async throws {
        try await sql.raw("DELETE FROM bean_varietals WHERE bean_id = \(bind: beanID)").run()
        try await sql.raw("DELETE FROM bean_flavor_notes WHERE bean_id = \(bind: beanID)").run()
        if !bean.varietalSlugs.isEmpty {
            try await sql.raw("""
                INSERT INTO bean_varietals (bean_id, varietal_slug)
                SELECT \(bind: beanID), unnest(\(bind: bean.varietalSlugs)::text[])
                """).run()
        }
        if !bean.flavorNoteSlugs.isEmpty {
            try await sql.raw("""
                INSERT INTO bean_flavor_notes (bean_id, flavor_note_slug)
                SELECT \(bind: beanID), unnest(\(bind: bean.flavorNoteSlugs)::text[])
                """).run()
        }
    }
}
