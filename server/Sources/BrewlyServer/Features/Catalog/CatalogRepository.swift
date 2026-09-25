import BrewlyAPI
import FluentKit
import SQLKit

protocol CatalogRepository: Sendable {
    func catalog() async throws -> CatalogDTO
    func brewMethod(slug: String) async throws -> BrewMethodDTO?
}

struct PostgresCatalogRepository: CatalogRepository {
    let database: any Database

    private struct BrewMethodRow: Decodable {
        var slug: String
        var name: String
        var category: String
        var ratioBasis: String
        var description: String?
        var defaultRatio: Double?
        var defaultGrindSize: String?
        var defaultWaterTempC: Double?

        var dto: BrewMethodDTO {
            BrewMethodDTO(
                slug: slug,
                name: name,
                category: MethodCategory(rawValue: category) ?? .other,
                ratioBasis: RatioBasis(rawValue: ratioBasis) ?? .water,
                description: description,
                defaultRatio: defaultRatio,
                defaultGrindSize: defaultGrindSize.flatMap(GrindSize.init(rawValue:)),
                defaultWaterTempC: defaultWaterTempC
            )
        }
    }

    private static let brewMethodColumns = """
        slug, name, category, ratio_basis, description, default_ratio::float8 AS default_ratio,
        default_grind_size::text AS default_grind_size, default_water_temp_c::float8 AS default_water_temp_c
        """

    func catalog() async throws -> CatalogDTO {
        let sql = database.sql

        let methods = try await sql.raw("""
            SELECT \(unsafeRaw: Self.brewMethodColumns) FROM brew_methods ORDER BY sort_order, name
            """).all().map { try $0.decodeSnakeCase(BrewMethodRow.self).dto }

        let varietals = try await sql.raw("SELECT slug, name, species FROM varietals ORDER BY name").all().map {
            VarietalDTO(
                slug: try $0.decode(column: "slug", as: String.self),
                name: try $0.decode(column: "name", as: String.self),
                species: CoffeeSpecies(rawValue: try $0.decode(column: "species", as: String.self)) ?? .arabica
            )
        }

        let processes = try await sql.raw("SELECT slug, name, description FROM processing_methods ORDER BY name")
            .all().map {
                ProcessingMethodDTO(
                    slug: try $0.decode(column: "slug", as: String.self),
                    name: try $0.decode(column: "name", as: String.self),
                    description: try $0.decode(column: "description", as: String?.self)
                )
            }

        let countries = try await sql.raw("SELECT code::text AS code, name FROM countries ORDER BY name").all().map {
            CountryDTO(
                code: try $0.decode(column: "code", as: String.self),
                name: try $0.decode(column: "name", as: String.self)
            )
        }

        let grinders = try await sql.raw("SELECT slug, brand, model, kind, burr_type FROM grinders ORDER BY brand, model")
            .all().map {
                GrinderDTO(
                    slug: try $0.decode(column: "slug", as: String.self),
                    brand: try $0.decode(column: "brand", as: String.self),
                    model: try $0.decode(column: "model", as: String.self),
                    kind: GrinderKind(rawValue: try $0.decode(column: "kind", as: String.self)) ?? .manual,
                    burrType: try $0.decode(column: "burr_type", as: String?.self).flatMap(BurrType.init(rawValue:))
                )
            }

        let flavorNotes = try await sql.raw("SELECT slug, name, category FROM flavor_notes ORDER BY category, name")
            .all().map {
                FlavorNoteDTO(
                    slug: try $0.decode(column: "slug", as: String.self),
                    name: try $0.decode(column: "name", as: String.self),
                    category: FlavorCategory(rawValue: try $0.decode(column: "category", as: String.self)) ?? .other
                )
            }

        return CatalogDTO(
            brewMethods: methods,
            varietals: varietals,
            processingMethods: processes,
            countries: countries,
            grinders: grinders,
            flavorNotes: flavorNotes
        )
    }

    func brewMethod(slug: String) async throws -> BrewMethodDTO? {
        try await database.sql.raw("""
            SELECT \(unsafeRaw: Self.brewMethodColumns) FROM brew_methods WHERE slug = \(bind: slug)
            """).first().map { try $0.decodeSnakeCase(BrewMethodRow.self).dto }
    }
}
