import BrewlyAPI
import FluentKit
import SQLKit
import Vapor

protocol EquipmentRepository: Sendable {
    func list(ownerID: UUID) async throws -> [EquipmentDTO]
    /// Whether `viewerID` may see the profile of `ownerID` (it exists and no block hides it).
    func canViewProfile(ownerID: UUID, viewerID: UUID) async throws -> Bool
    func create(ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO
    /// `nil` when the item does not exist or is not owned by `ownerID`.
    func update(id: UUID, ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO?
    /// `false` when the item does not exist or is not owned by `ownerID`.
    func delete(id: UUID, ownerID: UUID) async throws -> Bool
}

struct PostgresEquipmentRepository: EquipmentRepository {
    let database: any Database

    private struct EquipmentRow: Decodable {
        var id: UUID
        var kind: String
        var grinderSlug: String?
        var brand: String?
        var model: String?
        var nickname: String?
        var notes: String?
        var isDefault: Bool
        var settingMethods: [String]
        var settingValues: [String]
        var createdAt: Date

        var dto: EquipmentDTO {
            EquipmentDTO(
                id: id,
                kind: EquipmentKind(rawValue: kind) ?? .other,
                grinderSlug: grinderSlug,
                brand: brand,
                model: model,
                nickname: nickname,
                notes: notes,
                isDefault: isDefault,
                grindSettings: zip(settingMethods, settingValues).map {
                    GrindSettingInput(methodSlug: $0, grindSetting: $1)
                },
                createdAt: createdAt
            )
        }
    }

    private static let select = """
        SELECT e.id, e.kind, e.grinder_slug, e.brand, e.model, e.nickname, e.notes, e.is_default, e.created_at,
               coalesce((SELECT array_agg(s.method_slug ORDER BY s.method_slug)
                         FROM equipment_grind_settings s WHERE s.equipment_id = e.id), '{}') AS setting_methods,
               coalesce((SELECT array_agg(s.grind_setting ORDER BY s.method_slug)
                         FROM equipment_grind_settings s WHERE s.equipment_id = e.id), '{}') AS setting_values
        FROM user_equipment e
        """

    /// Kinds in the order the app shows them.
    private static let kindOrder = "ARRAY['grinder', 'brewer', 'espresso_machine', 'kettle', 'scale', 'other']"

    func list(ownerID: UUID) async throws -> [EquipmentDTO] {
        try await database.sql.raw("""
            \(unsafeRaw: Self.select)
            WHERE e.owner_id = \(bind: ownerID)
            ORDER BY array_position(\(unsafeRaw: Self.kindOrder), e.kind), e.is_default DESC, e.created_at, e.id
            """).all().map { try $0.decodeSnakeCase(EquipmentRow.self).dto }
    }

    func canViewProfile(ownerID: UUID, viewerID: UUID) async throws -> Bool {
        try await database.sql.raw("""
            SELECT 1 FROM users WHERE id = \(bind: ownerID) AND can_view_content(\(bind: viewerID), id, 'public')
            """).first() != nil
    }

    func create(ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO {
        try await database.transaction { tx in
            let sql = tx.sql
            if item.isDefault {
                try await Self.clearDefault(ownerID: ownerID, kind: item.kind, except: nil, sql: sql)
            }
            guard let row = try await sql.raw("""
                INSERT INTO user_equipment (owner_id, kind, grinder_slug, brand, model, nickname, notes, is_default)
                VALUES (\(bind: ownerID), \(bind: item.kind.rawValue), \(bind: item.grinderSlug), \(bind: item.brand),
                        \(bind: item.model), \(bind: item.nickname), \(bind: item.notes), \(bind: item.isDefault))
                RETURNING id
                """).first()
            else { throw AppError(status: .internalServerError, code: "internal_error", message: "Equipment was not created.") }
            let id = try row.decode(column: "id", as: UUID.self)
            try await Self.replaceSettings(equipmentID: id, item.grindSettings, sql: sql)
            guard let created = try await Self.find(id: id, sql: sql) else { throw AppError.notFound("Equipment") }
            return created
        }
    }

    func update(id: UUID, ownerID: UUID, _ item: UpsertEquipmentRequest) async throws -> EquipmentDTO? {
        try await database.transaction { tx in
            let sql = tx.sql
            if item.isDefault {
                try await Self.clearDefault(ownerID: ownerID, kind: item.kind, except: id, sql: sql)
            }
            let row = try await sql.raw("""
                UPDATE user_equipment SET
                    kind = \(bind: item.kind.rawValue), grinder_slug = \(bind: item.grinderSlug),
                    brand = \(bind: item.brand), model = \(bind: item.model), nickname = \(bind: item.nickname),
                    notes = \(bind: item.notes), is_default = \(bind: item.isDefault)
                WHERE id = \(bind: id) AND owner_id = \(bind: ownerID)
                RETURNING id
                """).first()
            guard row != nil else { return nil }
            try await Self.replaceSettings(equipmentID: id, item.grindSettings, sql: sql)
            return try await Self.find(id: id, sql: sql)
        }
    }

    func delete(id: UUID, ownerID: UUID) async throws -> Bool {
        try await database.sql.raw("""
            DELETE FROM user_equipment WHERE id = \(bind: id) AND owner_id = \(bind: ownerID) RETURNING id
            """).first() != nil
    }

    private static func find(id: UUID, sql: any SQLDatabase) async throws -> EquipmentDTO? {
        try await sql.raw("\(unsafeRaw: Self.select) WHERE e.id = \(bind: id)")
            .first()
            .map { try $0.decodeSnakeCase(EquipmentRow.self).dto }
    }

    /// Only one item per kind can be the default.
    private static func clearDefault(ownerID: UUID, kind: EquipmentKind, except id: UUID?, sql: any SQLDatabase) async throws {
        try await sql.raw("""
            UPDATE user_equipment SET is_default = false
            WHERE owner_id = \(bind: ownerID) AND kind = \(bind: kind.rawValue) AND is_default
              AND id IS DISTINCT FROM \(bind: id)
            """).run()
    }

    private static func replaceSettings(equipmentID: UUID, _ settings: [GrindSettingInput], sql: any SQLDatabase) async throws {
        try await sql.raw("DELETE FROM equipment_grind_settings WHERE equipment_id = \(bind: equipmentID)").run()
        guard !settings.isEmpty else { return }
        try await sql.raw("""
            INSERT INTO equipment_grind_settings (equipment_id, method_slug, grind_setting)
            SELECT \(bind: equipmentID), unnest(\(bind: settings.map(\.methodSlug))::text[]),
                   unnest(\(bind: settings.map(\.grindSetting))::text[])
            """).run()
    }
}
