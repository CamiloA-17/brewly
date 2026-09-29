import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

protocol BrewSessionRepository: Sendable {
    func list(userID: UUID, recipeID: UUID?, after: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<BrewSessionDTO>
    func create(userID: UUID, request: CreateBrewSessionRequest) async throws -> BrewSessionDTO?
}

struct PostgresBrewSessionRepository: BrewSessionRepository {
    let database: any Database

    private struct Row: Decodable {
        var id: UUID
        var recipeId: UUID?
        var recipeTitle: String
        var beanName: String
        var methodSlug: String
        var doseG: Double
        var waterG: Double?
        var yieldG: Double?
        var grindSetting: String?
        var waterTempC: Double?
        var elapsedS: Int
        var tdsPercent: Double?
        var extractionYieldPercent: Double?
        var rating: Int?
        var acidity: Int?
        var bitterness: Int?
        var body: Int?
        var notes: String?
        var createdAt: Date
        var cursorCreatedAt: String

        var dto: BrewSessionDTO {
            BrewSessionDTO(id: id, recipeId: recipeId, recipeTitle: recipeTitle,
                           beanName: beanName, methodSlug: methodSlug, doseG: doseG,
                           waterG: waterG, yieldG: yieldG, grindSetting: grindSetting,
                           waterTempC: waterTempC, elapsedS: elapsedS,
                           tdsPercent: tdsPercent, extractionYieldPercent: extractionYieldPercent,
                           rating: rating,
                           acidity: acidity, bitterness: bitterness, body: body,
                           notes: notes, createdAt: createdAt)
        }
    }

    private static let select = """
        SELECT id, recipe_id, recipe_title, bean_name, method_slug,
               dose_g::float8 AS dose_g, water_g::float8 AS water_g,
               yield_g::float8 AS yield_g, grind_setting,
               water_temp_c::float8 AS water_temp_c, elapsed_s,
               tds_percent::float8 AS tds_percent,
               extraction_yield_percent::float8 AS extraction_yield_percent,
               rating, acidity, bitterness, body, notes, created_at,
               \(PageCursor.sqlTimestamp("created_at")) AS cursor_created_at
        FROM brew_sessions
        """

    func list(userID: UUID, recipeID: UUID?, after cursor: PageCursor?, limit: Int) async throws -> BrewlyAPI.Page<BrewSessionDTO> {
        let cursorTime = cursor?.createdAt
        let cursorID = cursor?.id
        let rows = try await database.sql.raw("""
            \(unsafeRaw: Self.select)
            WHERE user_id = \(bind: userID)
              AND (\(bind: recipeID)::uuid IS NULL OR recipe_id = \(bind: recipeID))
              AND (\(bind: cursorTime)::timestamptz IS NULL
                   OR (created_at, id) < (\(bind: cursorTime)::timestamptz, \(bind: cursorID)::uuid))
            ORDER BY created_at DESC, id DESC LIMIT \(bind: limit + 1)
            """).all().map { try $0.decodeSnakeCase(Row.self) }
        let pageRows = rows.prefix(limit)
        let next = rows.count > limit
            ? pageRows.last.map { PageCursor(createdAt: $0.cursorCreatedAt, id: $0.id).encoded() }
            : nil
        return BrewlyAPI.Page(items: pageRows.map(\.dto), nextCursor: next)
    }

    func create(userID: UUID, request: CreateBrewSessionRequest) async throws -> BrewSessionDTO? {
        guard let inserted = try await database.sql.raw("""
            INSERT INTO brew_sessions
                (user_id, recipe_id, recipe_title, bean_name, method_slug,
                 dose_g, water_g, yield_g, grind_setting, water_temp_c,
                 elapsed_s, tds_percent, rating, acidity, bitterness, body, notes)
            SELECT \(bind: userID), r.id, r.title, b.name, r.method_slug,
                   \(bind: request.doseG), \(bind: request.waterG), \(bind: request.yieldG),
                   \(bind: request.grindSetting), \(bind: request.waterTempC),
                   \(bind: request.elapsedS), \(bind: request.tdsPercent), \(bind: request.rating), \(bind: request.acidity),
                   \(bind: request.bitterness), \(bind: request.body), \(bind: request.notes)
            FROM recipes r JOIN coffee_beans b ON b.id = r.bean_id
            WHERE r.id = \(bind: request.recipeId) AND r.author_id = \(bind: userID)
            RETURNING id
            """).first() else { return nil }
        let id = try inserted.decode(column: "id", as: UUID.self)
        guard let row = try await database.sql.raw("""
            \(unsafeRaw: Self.select) WHERE id = \(bind: id) AND user_id = \(bind: userID)
            """).first() else { return nil }
        return try row.decodeSnakeCase(Row.self).dto
    }
}
