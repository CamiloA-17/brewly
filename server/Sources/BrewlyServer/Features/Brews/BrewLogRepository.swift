import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

/// Optional filters of a member's journal.
struct BrewLogFilter: Sendable, Equatable {
    var beanID: UUID?
    var methodSlug: String?
}

protocol BrewLogRepository: Sendable {
    /// The member's own journal, most recent brew first.
    func list(userID: UUID, filter: BrewLogFilter, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<BrewLogDTO>
    /// The brew if `viewerID` is allowed to see it.
    func find(id: UUID, viewerID: UUID) async throws -> BrewLogDTO?
    func create(userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO
    /// `nil` when the brew does not exist or is not the member's.
    func update(id: UUID, userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO?
    /// `false` when the brew does not exist or is not the member's.
    func delete(id: UUID, userID: UUID) async throws -> Bool
}

struct PostgresBrewLogRepository: BrewLogRepository {
    let database: any Database

    private struct BrewRow: Decodable {
        var id: UUID
        var userId: UUID
        var username: String
        var displayName: String
        var avatarUrl: String?
        var recipeId: UUID?
        var recipeTitle: String?
        var recipeAuthorId: UUID?
        var recipeAuthorUsername: String?
        var recipeAuthorDisplayName: String?
        var recipeAuthorAvatarUrl: String?
        var beanId: UUID
        var beanName: String
        var beanRoaster: String?
        var beanCountryCode: String?
        var beanFarm: String?
        var beanProcessingMethodSlug: String?
        var beanRoastLevel: String?
        var beanVarietalSlugs: [String]
        var methodSlug: String
        var equipmentId: UUID?
        var brewedAt: Date
        var cursorBrewedAt: String
        var doseG: Double
        var waterG: Double?
        var yieldG: Double?
        var ratio: Double?
        var grindSize: String?
        var grindSetting: String?
        var waterTempC: Double?
        var totalTimeS: Int?
        var rating: Int?
        var acidity: Int?
        var sweetness: Int?
        var body: Int?
        var bitterness: Int?
        var aftertaste: Int?
        var tdsPercent: Double?
        var extractionYieldPercent: Double?
        var flavorNoteSlugs: [String]
        var notes: String?
        var photoMediaId: UUID?
        var visibility: String
        var createdAt: Date

        var dto: BrewLogDTO {
            BrewLogDTO(
                id: id,
                user: UserSummaryDTO(id: userId, username: username, displayName: displayName, avatarURL: avatarUrl),
                recipe: recipe,
                bean: BeanSummaryDTO(
                    id: beanId,
                    name: beanName,
                    roaster: beanRoaster,
                    countryCode: beanCountryCode,
                    farm: beanFarm,
                    processingMethodSlug: beanProcessingMethodSlug,
                    varietalSlugs: beanVarietalSlugs,
                    roastLevel: beanRoastLevel.flatMap(RoastLevel.init(rawValue:))
                ),
                methodSlug: methodSlug,
                equipmentId: equipmentId,
                brewedAt: brewedAt,
                doseG: doseG,
                waterG: waterG,
                yieldG: yieldG,
                ratio: ratio,
                grindSize: grindSize.flatMap(GrindSize.init(rawValue:)),
                grindSetting: grindSetting,
                waterTempC: waterTempC,
                totalTimeS: totalTimeS,
                rating: rating,
                acidity: acidity,
                sweetness: sweetness,
                body: body,
                bitterness: bitterness,
                aftertaste: aftertaste,
                tdsPercent: tdsPercent,
                extractionYieldPercent: extractionYieldPercent,
                flavorNoteSlugs: flavorNoteSlugs,
                notes: notes,
                photoURL: photoMediaId.map(PostgresMediaRepository.url(for:)),
                visibility: Visibility(rawValue: visibility) ?? .private,
                createdAt: createdAt
            )
        }

        private var recipe: RecipeReferenceDTO? {
            guard let recipeId, let recipeTitle, let recipeAuthorId, let recipeAuthorUsername,
                  let recipeAuthorDisplayName
            else { return nil }
            return RecipeReferenceDTO(
                id: recipeId,
                title: recipeTitle,
                author: UserSummaryDTO(
                    id: recipeAuthorId, username: recipeAuthorUsername,
                    displayName: recipeAuthorDisplayName, avatarURL: recipeAuthorAvatarUrl
                )
            )
        }
    }

    /// Needs a `viewer` CTE with the viewer's id; the followed recipe only shows when visible.
    private static let select = """
        SELECT bl.id, bl.user_id, u.username, u.display_name, u.avatar_url,
               r.id AS recipe_id, r.title AS recipe_title, ru.id AS recipe_author_id,
               ru.username AS recipe_author_username, ru.display_name AS recipe_author_display_name,
               ru.avatar_url AS recipe_author_avatar_url,
               b.id AS bean_id, b.name AS bean_name, b.roaster AS bean_roaster,
               b.country_code::text AS bean_country_code, b.farm AS bean_farm,
               b.processing_method_slug AS bean_processing_method_slug, b.roast_level::text AS bean_roast_level,
               coalesce((SELECT array_agg(bv.varietal_slug ORDER BY bv.varietal_slug)
                         FROM bean_varietals bv WHERE bv.bean_id = b.id), '{}') AS bean_varietal_slugs,
               bl.method_slug, bl.equipment_id, bl.brewed_at,
               \(PageCursor.sqlTimestamp("bl.brewed_at")) AS cursor_brewed_at,
               bl.dose_g::float8 AS dose_g, bl.water_g::float8 AS water_g, bl.yield_g::float8 AS yield_g,
               bl.ratio::float8 AS ratio, bl.grind_size::text AS grind_size, bl.grind_setting,
               bl.water_temp_c::float8 AS water_temp_c, bl.total_time_s,
               bl.rating, bl.acidity, bl.sweetness, bl.body, bl.bitterness, bl.aftertaste,
               bl.tds_percent::float8 AS tds_percent, bl.extraction_yield_percent::float8 AS extraction_yield_percent,
               coalesce((SELECT array_agg(fn.flavor_note_slug ORDER BY fn.flavor_note_slug)
                         FROM brew_log_flavor_notes fn WHERE fn.brew_log_id = bl.id), '{}') AS flavor_note_slugs,
               bl.notes, bl.photo_media_id, bl.visibility::text AS visibility, bl.created_at
        FROM brew_logs bl
        CROSS JOIN viewer v
        JOIN users u ON u.id = bl.user_id
        JOIN coffee_beans b ON b.id = bl.bean_id
        LEFT JOIN recipes r ON r.id = bl.recipe_id AND can_view_content(v.viewer_id, r.author_id, r.visibility)
        LEFT JOIN users ru ON ru.id = r.author_id
        """

    func list(userID: UUID, filter: BrewLogFilter, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<BrewLogDTO> {
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let rows = try await database.sql.raw("""
            WITH viewer AS (SELECT \(bind: userID)::uuid AS viewer_id)
            \(unsafeRaw: Self.select)
            WHERE bl.user_id = \(bind: userID)
              AND (\(bind: filter.beanID)::uuid IS NULL OR bl.bean_id = \(bind: filter.beanID))
              AND (\(bind: filter.methodSlug)::text IS NULL OR bl.method_slug = \(bind: filter.methodSlug))
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (bl.brewed_at, bl.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY bl.brewed_at DESC, bl.id DESC
            LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(BrewRow.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorBrewedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: nextCursor)
    }

    func find(id: UUID, viewerID: UUID) async throws -> BrewLogDTO? {
        try await Self.find(id: id, viewerID: viewerID, sql: database.sql)
    }

    private static func find(id: UUID, viewerID: UUID, sql: any SQLDatabase) async throws -> BrewLogDTO? {
        try await sql.raw("""
            WITH viewer AS (SELECT \(bind: viewerID)::uuid AS viewer_id)
            \(unsafeRaw: Self.select)
            WHERE bl.id = \(bind: id) AND can_view_content(\(bind: viewerID), bl.user_id, bl.visibility)
            """).first().map { try $0.decodeSnakeCase(BrewRow.self).dto }
    }

    func create(userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO {
        try await database.transaction { tx in
            let sql = tx.sql
            try await PostgresMediaRepository.checkUsable(brew.photoMediaId, ownerID: userID, current: nil, sql: sql)
            guard let row = try await sql.raw("""
                INSERT INTO brew_logs
                    (user_id, recipe_id, bean_id, method_slug, equipment_id, brewed_at, dose_g, water_g, yield_g,
                     grind_size, grind_setting, water_temp_c, total_time_s, rating, acidity, sweetness, body,
                     bitterness, aftertaste, tds_percent, notes, photo_media_id, visibility)
                VALUES
                    (\(bind: userID), \(bind: brew.recipeId), \(bind: brew.beanId), \(bind: brew.methodSlug),
                     \(bind: brew.equipmentId), \(bind: brew.brewedAt), \(bind: brew.doseG), \(bind: brew.waterG),
                     \(bind: brew.yieldG), \(bind: brew.grindSize?.rawValue), \(bind: brew.grindSetting),
                     \(bind: brew.waterTempC), \(bind: brew.totalTimeS), \(bind: brew.rating), \(bind: brew.acidity),
                     \(bind: brew.sweetness), \(bind: brew.body), \(bind: brew.bitterness), \(bind: brew.aftertaste),
                     \(bind: brew.tdsPercent), \(bind: brew.notes), \(bind: brew.photoMediaId),
                     \(bind: brew.visibility.rawValue))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: APIErrorCode.internalError, message: "Brew was not created.") }
            let id = try row.decode(column: "id", as: UUID.self)
            try await Self.replaceFlavorNotes(brewID: id, brew.flavorNoteSlugs, sql: sql)
            try await Self.consume(beanID: brew.beanId, doseG: brew.doseG, userID: userID, sql: sql)
            guard let created = try await Self.find(id: id, viewerID: userID, sql: sql) else {
                throw AppError.notFound("Brew")
            }
            return created
        }
    }

    func update(id: UUID, userID: UUID, _ brew: UpsertBrewLogRequest) async throws -> BrewLogDTO? {
        try await database.transaction { tx in
            let sql = tx.sql
            guard let previous = try await Self.lockedBrew(id: id, userID: userID, sql: sql) else { return nil }
            try await PostgresMediaRepository.checkUsable(
                brew.photoMediaId, ownerID: userID, current: previous.photoMediaId, sql: sql
            )
            try await Self.restore(beanID: previous.beanId, doseG: previous.doseG, userID: userID, sql: sql)
            try await sql.raw("""
                UPDATE brew_logs SET
                    recipe_id = \(bind: brew.recipeId), bean_id = \(bind: brew.beanId),
                    method_slug = \(bind: brew.methodSlug), equipment_id = \(bind: brew.equipmentId),
                    brewed_at = \(bind: brew.brewedAt), dose_g = \(bind: brew.doseG), water_g = \(bind: brew.waterG),
                    yield_g = \(bind: brew.yieldG), grind_size = \(bind: brew.grindSize?.rawValue),
                    grind_setting = \(bind: brew.grindSetting), water_temp_c = \(bind: brew.waterTempC),
                    total_time_s = \(bind: brew.totalTimeS), rating = \(bind: brew.rating),
                    acidity = \(bind: brew.acidity), sweetness = \(bind: brew.sweetness), body = \(bind: brew.body),
                    bitterness = \(bind: brew.bitterness), aftertaste = \(bind: brew.aftertaste),
                    tds_percent = \(bind: brew.tdsPercent), notes = \(bind: brew.notes),
                    photo_media_id = \(bind: brew.photoMediaId), visibility = \(bind: brew.visibility.rawValue)
                WHERE id = \(bind: id)
                """).run()
            try await Self.replaceFlavorNotes(brewID: id, brew.flavorNoteSlugs, sql: sql)
            try await Self.consume(beanID: brew.beanId, doseG: brew.doseG, userID: userID, sql: sql)
            try await PostgresMediaRepository.deleteReplaced(previous.photoMediaId, by: brew.photoMediaId, sql: sql)
            return try await Self.find(id: id, viewerID: userID, sql: sql)
        }
    }

    func delete(id: UUID, userID: UUID) async throws -> Bool {
        try await database.transaction { tx in
            let sql = tx.sql
            guard let previous = try await Self.lockedBrew(id: id, userID: userID, sql: sql) else { return false }
            try await sql.raw("DELETE FROM brew_logs WHERE id = \(bind: id)").run()
            // Deleting a brew gives its coffee back to the bag.
            try await Self.restore(beanID: previous.beanId, doseG: previous.doseG, userID: userID, sql: sql)
            try await PostgresMediaRepository.deleteReplaced(previous.photoMediaId, by: nil, sql: sql)
            return true
        }
    }

    // MARK: - Helpers

    private struct StoredBrew: Decodable {
        var beanId: UUID
        var doseG: Double
        var photoMediaId: UUID?
    }

    private static func lockedBrew(id: UUID, userID: UUID, sql: any SQLDatabase) async throws -> StoredBrew? {
        try await sql.raw("""
            SELECT bean_id, dose_g::float8 AS dose_g, photo_media_id FROM brew_logs
            WHERE id = \(bind: id) AND user_id = \(bind: userID)
            FOR UPDATE
            """).first().map { try $0.decodeSnakeCase(StoredBrew.self) }
    }

    private static func replaceFlavorNotes(brewID: UUID, _ slugs: [String], sql: any SQLDatabase) async throws {
        try await sql.raw("DELETE FROM brew_log_flavor_notes WHERE brew_log_id = \(bind: brewID)").run()
        guard !slugs.isEmpty else { return }
        try await sql.raw("""
            INSERT INTO brew_log_flavor_notes (brew_log_id, flavor_note_slug)
            SELECT \(bind: brewID), unnest(\(bind: slugs)::text[])
            """).run()
    }

    /// Subtracts the dose from the bag, without going below zero.
    private static func consume(beanID: UUID, doseG: Double, userID: UUID, sql: any SQLDatabase) async throws {
        try await sql.raw("""
            UPDATE coffee_beans SET remaining_g = greatest(remaining_g - \(bind: doseG)::numeric, 0)
            WHERE id = \(bind: beanID) AND owner_id = \(bind: userID) AND remaining_g IS NOT NULL
            """).run()
    }

    /// Gives the dose back to the bag, never above its original weight.
    private static func restore(beanID: UUID, doseG: Double, userID: UUID, sql: any SQLDatabase) async throws {
        try await sql.raw("""
            UPDATE coffee_beans
            SET remaining_g = least(remaining_g + \(bind: doseG)::numeric, coalesce(weight_g, 100000))
            WHERE id = \(bind: beanID) AND owner_id = \(bind: userID) AND remaining_g IS NOT NULL
            """).run()
    }
}
