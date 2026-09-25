import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

/// Which recipes a list returns.
enum RecipeListScope: Sendable {
    /// Every recipe of the author, whatever its visibility.
    case authoredBy(UUID)
    /// Recipes of another member that the viewer is allowed to see.
    case visibleFrom(authorID: UUID)
    /// Recipes the viewer saved, newest save first.
    case savedByViewer
    /// Public recipes of the community, optionally filtered.
    case explore(methodSlug: String?, countryCode: String?, varietalSlug: String?)
}

protocol RecipeRepository: Sendable {
    func list(scope: RecipeListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<RecipeSummaryDTO>
    /// The recipe if `viewerID` is allowed to see it.
    func find(id: UUID, viewerID: UUID) async throws -> RecipeDTO?
    func create(authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO
    /// `nil` when the recipe does not exist or is not authored by `authorID`.
    func update(id: UUID, authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO?
    /// `false` when the recipe does not exist or is not authored by `authorID`.
    func delete(id: UUID, authorID: UUID) async throws -> Bool
    /// Saves the recipe for the user. `nil` when the recipe does not exist or the user can't see it.
    func save(id: UUID, userID: UUID) async throws -> SaveStateDTO?
    func unsave(id: UUID, userID: UUID) async throws -> SaveStateDTO
}

struct PostgresRecipeRepository: RecipeRepository {
    let database: any Database

    // MARK: - Rows

    private struct SummaryRow: Decodable {
        var id: UUID
        var title: String
        var methodSlug: String
        var doseG: Double
        var ratio: Double
        var grindSize: String
        var waterTempC: Double?
        var totalTimeS: Int?
        var rating: Int?
        var visibility: String
        var createdAt: Date
        var cursorCreatedAt: String
        var beanName: String
        var authorId: UUID
        var authorUsername: String
        var authorDisplayName: String
        var authorAvatarUrl: String?

        var dto: RecipeSummaryDTO {
            RecipeSummaryDTO(
                id: id,
                author: UserSummaryDTO(
                    id: authorId, username: authorUsername, displayName: authorDisplayName, avatarURL: authorAvatarUrl
                ),
                beanName: beanName,
                methodSlug: methodSlug,
                title: title,
                doseG: doseG,
                ratio: ratio,
                grindSize: GrindSize(rawValue: grindSize) ?? .medium,
                waterTempC: waterTempC,
                totalTimeS: totalTimeS,
                rating: rating,
                visibility: Visibility(rawValue: visibility) ?? .private,
                createdAt: createdAt
            )
        }
    }

    private struct DetailRow: Decodable {
        var id: UUID
        var methodSlug: String
        var forkedFromId: UUID?
        var forkedFromTitle: String?
        var forkedFromAuthorId: UUID?
        var forkedFromAuthorUsername: String?
        var forkedFromAuthorDisplayName: String?
        var forkedFromAuthorAvatarUrl: String?
        var title: String
        var description: String?
        var doseG: Double
        var waterG: Double?
        var yieldG: Double?
        var ratio: Double
        var grindSize: String
        var grinderSlug: String?
        var grindSetting: String?
        var grindMicrons: Int?
        var waterTempC: Double?
        var bloomWaterG: Double?
        var bloomTimeS: Int?
        var totalTimeS: Int?
        var pressureBar: Double?
        var filterType: String?
        var waterProfile: String?
        var waterTdsPpm: Int?
        var tdsPercent: Double?
        var extractionYieldPercent: Double?
        var rating: Int?
        var notes: String?
        var visibility: String
        var saveCount: Int
        var forkCount: Int
        var isSaved: Bool
        var createdAt: Date
        var updatedAt: Date
        var flavorNoteSlugs: [String]
        var authorId: UUID
        var authorUsername: String
        var authorDisplayName: String
        var authorAvatarUrl: String?
        var beanId: UUID
        var beanName: String
        var beanRoaster: String?
        var beanCountryCode: String?
        var beanFarm: String?
        var beanProcessingMethodSlug: String?
        var beanRoastLevel: String?
        var beanVarietalSlugs: [String]

        func dto(steps: [RecipeStepDTO]) -> RecipeDTO {
            RecipeDTO(
                id: id,
                author: UserSummaryDTO(
                    id: authorId, username: authorUsername, displayName: authorDisplayName, avatarURL: authorAvatarUrl
                ),
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
                forkedFromId: forkedFromId,
                forkedFrom: forkedFrom,
                title: title,
                description: description,
                doseG: doseG,
                waterG: waterG,
                yieldG: yieldG,
                ratio: ratio,
                grindSize: GrindSize(rawValue: grindSize) ?? .medium,
                grinderSlug: grinderSlug,
                grindSetting: grindSetting,
                grindMicrons: grindMicrons,
                waterTempC: waterTempC,
                bloomWaterG: bloomWaterG,
                bloomTimeS: bloomTimeS,
                totalTimeS: totalTimeS,
                pressureBar: pressureBar,
                filterType: filterType.flatMap(FilterType.init(rawValue:)),
                waterProfile: waterProfile,
                waterTdsPpm: waterTdsPpm,
                tdsPercent: tdsPercent,
                extractionYieldPercent: extractionYieldPercent,
                rating: rating,
                notes: notes,
                flavorNoteSlugs: flavorNoteSlugs,
                steps: steps,
                visibility: Visibility(rawValue: visibility) ?? .private,
                saveCount: saveCount,
                forkCount: forkCount,
                isSaved: isSaved,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        private var forkedFrom: RecipeReferenceDTO? {
            guard let forkedFromId, let forkedFromTitle, let forkedFromAuthorId,
                  let forkedFromAuthorUsername, let forkedFromAuthorDisplayName
            else { return nil }
            return RecipeReferenceDTO(
                id: forkedFromId,
                title: forkedFromTitle,
                author: UserSummaryDTO(
                    id: forkedFromAuthorId, username: forkedFromAuthorUsername,
                    displayName: forkedFromAuthorDisplayName, avatarURL: forkedFromAuthorAvatarUrl
                )
            )
        }
    }

    private struct StepRow: Decodable {
        var position: Int
        var kind: String
        var startS: Int
        var waterTargetG: Double?
        var instruction: String?
    }

    // MARK: - SQL fragments

    /// `cursorColumn` is the timestamp the list is ordered by.
    private static func summarySelect(cursorColumn: String = "r.created_at") -> String {
        """
        SELECT r.id, r.title, r.method_slug, r.dose_g::float8 AS dose_g, r.ratio::float8 AS ratio,
               r.grind_size::text AS grind_size, r.water_temp_c::float8 AS water_temp_c, r.total_time_s,
               r.rating, r.visibility::text AS visibility, r.created_at,
               \(PageCursor.sqlTimestamp(cursorColumn)) AS cursor_created_at,
               b.name AS bean_name, u.id AS author_id, u.username AS author_username,
               u.display_name AS author_display_name, u.avatar_url AS author_avatar_url
        FROM recipes r
        JOIN coffee_beans b ON b.id = r.bean_id
        JOIN users u ON u.id = r.author_id
        """
    }

    private static let detailSelect = """
        SELECT r.id, r.method_slug, r.forked_from_id,
               o.title AS forked_from_title, ou.id AS forked_from_author_id,
               ou.username AS forked_from_author_username, ou.display_name AS forked_from_author_display_name,
               ou.avatar_url AS forked_from_author_avatar_url,
               r.title, r.description,
               r.dose_g::float8 AS dose_g, r.water_g::float8 AS water_g, r.yield_g::float8 AS yield_g,
               r.ratio::float8 AS ratio, r.grind_size::text AS grind_size, r.grinder_slug, r.grind_setting,
               r.grind_microns, r.water_temp_c::float8 AS water_temp_c, r.bloom_water_g::float8 AS bloom_water_g,
               r.bloom_time_s, r.total_time_s, r.pressure_bar::float8 AS pressure_bar, r.filter_type,
               r.water_profile, r.water_tds_ppm, r.tds_percent::float8 AS tds_percent,
               r.extraction_yield_percent::float8 AS extraction_yield_percent, r.rating, r.notes,
               r.visibility::text AS visibility, r.created_at, r.updated_at,
               (SELECT count(*) FROM recipe_saves s WHERE s.recipe_id = r.id)::int AS save_count,
               (SELECT count(*) FROM recipes f WHERE f.forked_from_id = r.id)::int AS fork_count,
               EXISTS (SELECT 1 FROM recipe_saves s WHERE s.recipe_id = r.id AND s.user_id = v.viewer_id) AS is_saved,
               coalesce((SELECT array_agg(fn.flavor_note_slug ORDER BY fn.flavor_note_slug)
                         FROM recipe_flavor_notes fn WHERE fn.recipe_id = r.id), '{}') AS flavor_note_slugs,
               u.id AS author_id, u.username AS author_username, u.display_name AS author_display_name,
               u.avatar_url AS author_avatar_url,
               b.id AS bean_id, b.name AS bean_name, b.roaster AS bean_roaster,
               b.country_code::text AS bean_country_code, b.farm AS bean_farm,
               b.processing_method_slug AS bean_processing_method_slug, b.roast_level::text AS bean_roast_level,
               coalesce((SELECT array_agg(v.varietal_slug ORDER BY v.varietal_slug)
                         FROM bean_varietals v WHERE v.bean_id = b.id), '{}') AS bean_varietal_slugs
        FROM recipes r
        CROSS JOIN viewer v
        JOIN users u ON u.id = r.author_id
        JOIN coffee_beans b ON b.id = r.bean_id
        -- The original of a remix is only shown to viewers who can see it.
        LEFT JOIN recipes o ON o.id = r.forked_from_id AND can_view_content(v.viewer_id, o.author_id, o.visibility)
        LEFT JOIN users ou ON ou.id = o.author_id
        """

    // MARK: - Queries

    func list(scope: RecipeListScope, viewerID: UUID, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<RecipeSummaryDTO> {
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let fetchLimit = limit + 1
        let query: SQLQueryString

        switch scope {
        case let .authoredBy(authorID):
            query = """
                \(unsafeRaw: Self.summarySelect())
                WHERE r.author_id = \(bind: authorID)
                  AND (\(bind: cursorTime)::timestamptz IS NULL
                       OR (r.created_at, r.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
                ORDER BY r.created_at DESC, r.id DESC
                LIMIT \(bind: fetchLimit)
                """
        case let .visibleFrom(authorID):
            query = """
                \(unsafeRaw: Self.summarySelect())
                WHERE r.author_id = \(bind: authorID)
                  AND can_view_content(\(bind: viewerID), r.author_id, r.visibility)
                  AND (\(bind: cursorTime)::timestamptz IS NULL
                       OR (r.created_at, r.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
                ORDER BY r.created_at DESC, r.id DESC
                LIMIT \(bind: fetchLimit)
                """
        case .savedByViewer:
            // Saved recipes that are no longer visible (made private, author blocked) are hidden.
            query = """
                \(unsafeRaw: Self.summarySelect(cursorColumn: "s.created_at"))
                JOIN recipe_saves s ON s.recipe_id = r.id AND s.user_id = \(bind: viewerID)
                WHERE can_view_content(\(bind: viewerID), r.author_id, r.visibility)
                  AND (\(bind: cursorTime)::timestamptz IS NULL
                       OR (s.created_at, r.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
                ORDER BY s.created_at DESC, r.id DESC
                LIMIT \(bind: fetchLimit)
                """
        case let .explore(methodSlug, countryCode, varietalSlug):
            query = """
                \(unsafeRaw: Self.summarySelect())
                WHERE r.visibility = 'public'
                  AND can_view_content(\(bind: viewerID), r.author_id, r.visibility)
                  AND (\(bind: methodSlug)::text IS NULL OR r.method_slug = \(bind: methodSlug))
                  AND (\(bind: countryCode)::text IS NULL OR b.country_code::text = \(bind: countryCode))
                  AND (\(bind: varietalSlug)::text IS NULL OR EXISTS (
                        SELECT 1 FROM bean_varietals bv
                        WHERE bv.bean_id = b.id AND bv.varietal_slug = \(bind: varietalSlug)))
                  AND (\(bind: cursorTime)::timestamptz IS NULL
                       OR (r.created_at, r.id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
                ORDER BY r.created_at DESC, r.id DESC
                LIMIT \(bind: fetchLimit)
                """
        }

        let rows = try await database.sql.raw(query).all().map { try $0.decodeSnakeCase(SummaryRow.self) }
        let pageRows = rows.prefix(limit)
        let nextCursor = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorCreatedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: nextCursor)
    }

    func find(id: UUID, viewerID: UUID) async throws -> RecipeDTO? {
        try await Self.find(id: id, viewerID: viewerID, sql: database.sql)
    }

    private static func find(id: UUID, viewerID: UUID, sql: any SQLDatabase) async throws -> RecipeDTO? {
        guard let row = try await sql.raw("""
            WITH viewer AS (SELECT \(bind: viewerID)::uuid AS viewer_id)
            \(unsafeRaw: Self.detailSelect)
            WHERE r.id = \(bind: id) AND can_view_content(\(bind: viewerID), r.author_id, r.visibility)
            """).first()
        else { return nil }
        let detail = try row.decodeSnakeCase(DetailRow.self)

        let steps = try await sql.raw("""
            SELECT position, kind, start_s, water_target_g::float8 AS water_target_g, instruction
            FROM recipe_steps WHERE recipe_id = \(bind: id) ORDER BY position
            """).all().map { row in
                let step = try row.decodeSnakeCase(StepRow.self)
                return RecipeStepDTO(
                    position: step.position,
                    kind: BrewStepKind(rawValue: step.kind) ?? .other,
                    startS: step.startS,
                    waterTargetG: step.waterTargetG,
                    instruction: step.instruction
                )
            }
        return detail.dto(steps: steps)
    }

    // MARK: - Commands

    func create(authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO {
        try await database.transaction { tx in
            let sql = tx.sql
            guard let row = try await sql.raw("""
                INSERT INTO recipes
                    (author_id, bean_id, forked_from_id, method_slug, title, description, dose_g, water_g, yield_g, grind_size,
                     grinder_slug, grind_setting, grind_microns, water_temp_c, bloom_water_g, bloom_time_s,
                     total_time_s, pressure_bar, filter_type, water_profile, water_tds_ppm, tds_percent, rating,
                     notes, visibility)
                VALUES
                    (\(bind: authorID), \(bind: recipe.beanId), \(bind: recipe.forkedFromId), \(bind: recipe.methodSlug), \(bind: recipe.title),
                     \(bind: recipe.description), \(bind: recipe.doseG), \(bind: recipe.waterG), \(bind: recipe.yieldG),
                     \(bind: recipe.grindSize.rawValue), \(bind: recipe.grinderSlug), \(bind: recipe.grindSetting),
                     \(bind: recipe.grindMicrons), \(bind: recipe.waterTempC), \(bind: recipe.bloomWaterG),
                     \(bind: recipe.bloomTimeS), \(bind: recipe.totalTimeS), \(bind: recipe.pressureBar),
                     \(bind: recipe.filterType?.rawValue), \(bind: recipe.waterProfile), \(bind: recipe.waterTdsPpm),
                     \(bind: recipe.tdsPercent), \(bind: recipe.rating), \(bind: recipe.notes),
                     \(bind: recipe.visibility.rawValue))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: "internal_error", message: "Recipe was not created.") }
            let id = try row.decode(column: "id", as: UUID.self)
            try await Self.replaceChildren(recipeID: id, recipe, sql: sql)
            if recipe.forkedFromId != nil {
                try await NotificationWriter.recipeForked(remixID: id, sql: sql)
            }
            guard let created = try await Self.find(id: id, viewerID: authorID, sql: sql) else {
                throw AppError.notFound("Recipe")
            }
            return created
        }
    }

    func update(id: UUID, authorID: UUID, _ recipe: UpsertRecipeRequest) async throws -> RecipeDTO? {
        try await database.transaction { tx in
            let sql = tx.sql
            let row = try await sql.raw("""
                UPDATE recipes SET
                    bean_id = \(bind: recipe.beanId), method_slug = \(bind: recipe.methodSlug),
                    title = \(bind: recipe.title), description = \(bind: recipe.description),
                    dose_g = \(bind: recipe.doseG), water_g = \(bind: recipe.waterG), yield_g = \(bind: recipe.yieldG),
                    grind_size = \(bind: recipe.grindSize.rawValue), grinder_slug = \(bind: recipe.grinderSlug),
                    grind_setting = \(bind: recipe.grindSetting), grind_microns = \(bind: recipe.grindMicrons),
                    water_temp_c = \(bind: recipe.waterTempC), bloom_water_g = \(bind: recipe.bloomWaterG),
                    bloom_time_s = \(bind: recipe.bloomTimeS), total_time_s = \(bind: recipe.totalTimeS),
                    pressure_bar = \(bind: recipe.pressureBar), filter_type = \(bind: recipe.filterType?.rawValue),
                    water_profile = \(bind: recipe.waterProfile), water_tds_ppm = \(bind: recipe.waterTdsPpm),
                    tds_percent = \(bind: recipe.tdsPercent), rating = \(bind: recipe.rating),
                    notes = \(bind: recipe.notes), visibility = \(bind: recipe.visibility.rawValue)
                WHERE id = \(bind: id) AND author_id = \(bind: authorID)
                RETURNING id
                """).first()
            guard row != nil else { return nil }
            try await Self.replaceChildren(recipeID: id, recipe, sql: sql)
            return try await Self.find(id: id, viewerID: authorID, sql: sql)
        }
    }

    func delete(id: UUID, authorID: UUID) async throws -> Bool {
        try await database.sql.raw("""
            DELETE FROM recipes WHERE id = \(bind: id) AND author_id = \(bind: authorID) RETURNING id
            """).first() != nil
    }

    func save(id: UUID, userID: UUID) async throws -> SaveStateDTO? {
        // The main query can't see rows inserted by the CTE, so the new save is added to the count.
        try await database.sql.raw("""
            WITH target AS (
                SELECT r.id FROM recipes r
                WHERE r.id = \(bind: id) AND can_view_content(\(bind: userID), r.author_id, r.visibility)
            ),
            inserted AS (
                INSERT INTO recipe_saves (user_id, recipe_id)
                SELECT \(bind: userID), id FROM target
                ON CONFLICT DO NOTHING
                RETURNING recipe_id
            ),
            notified AS (
                INSERT INTO notifications (recipient_id, actor_id, kind, recipe_id)
                SELECT r.author_id, \(bind: userID), 'recipe_save', r.id
                FROM inserted i JOIN recipes r ON r.id = i.recipe_id
                WHERE r.author_id <> \(bind: userID)
                ON CONFLICT DO NOTHING
            )
            SELECT ((SELECT count(*) FROM recipe_saves s WHERE s.recipe_id = t.id)
                    + (SELECT count(*) FROM inserted))::int AS save_count
            FROM target t
            """).first().map { SaveStateDTO(isSaved: true, saveCount: try $0.decode(column: "save_count", as: Int.self)) }
    }

    func unsave(id: UUID, userID: UUID) async throws -> SaveStateDTO {
        let row = try await database.sql.raw("""
            WITH deleted AS (
                DELETE FROM recipe_saves WHERE user_id = \(bind: userID) AND recipe_id = \(bind: id)
                RETURNING recipe_id
            ),
            retracted AS (
                DELETE FROM notifications
                WHERE kind = 'recipe_save' AND actor_id = \(bind: userID) AND recipe_id = \(bind: id)
            )
            SELECT ((SELECT count(*) FROM recipe_saves s WHERE s.recipe_id = \(bind: id))
                    - (SELECT count(*) FROM deleted))::int AS save_count
            """).first()
        return SaveStateDTO(isSaved: false, saveCount: try row?.decode(column: "save_count", as: Int.self) ?? 0)
    }

    /// Replaces the steps and tasting notes of a recipe.
    private static func replaceChildren(recipeID: UUID, _ recipe: UpsertRecipeRequest, sql: any SQLDatabase) async throws {
        try await sql.raw("DELETE FROM recipe_steps WHERE recipe_id = \(bind: recipeID)").run()
        try await sql.raw("DELETE FROM recipe_flavor_notes WHERE recipe_id = \(bind: recipeID)").run()

        for (index, step) in recipe.steps.enumerated() {
            try await sql.raw("""
                INSERT INTO recipe_steps (recipe_id, position, kind, start_s, water_target_g, instruction)
                VALUES (\(bind: recipeID), \(bind: index + 1), \(bind: step.kind.rawValue), \(bind: step.startS),
                        \(bind: step.waterTargetG), \(bind: step.instruction))
                """).run()
        }
        if !recipe.flavorNoteSlugs.isEmpty {
            try await sql.raw("""
                INSERT INTO recipe_flavor_notes (recipe_id, flavor_note_slug)
                SELECT \(bind: recipeID), unnest(\(bind: recipe.flavorNoteSlugs)::text[])
                """).run()
        }
    }
}
