@testable import BrewlyDomain
import XCTest

final class CodingTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: raw) ?? .distantPast
        }
        return decoder
    }

    func testRecipeDecodesEmbeddedRelationsAndSortsSteps() throws {
        let json = """
        {
          "id": "30000000-0000-0000-0000-000000000001",
          "owner_id": "00000000-0000-0000-0000-00000000000a",
          "title": "V60 dulce",
          "description": null,
          "brew_method_id": "40000000-0000-0000-0000-000000000001",
          "bean_id": null, "grinder_id": null, "brewer_id": null,
          "dose_g": 15, "water_g": 250, "yield_g": null, "ratio": 16.67,
          "water_temp_c": 94, "grind_size": null, "grind_setting": "24",
          "total_time_s": 180, "forked_from_id": null, "visibility": "public",
          "created_at": "2026-09-24T10:00:00Z",
          "method": {
            "id": "40000000-0000-0000-0000-000000000001", "owner_id": null, "slug": "v60",
            "name": "Hario V60", "category": "pour_over", "description": null, "icon": "drop.fill",
            "default_params": {"dose_g": 15, "water_g": 250}
          },
          "steps": [
            {"id": "50000000-0000-0000-0000-000000000002", "position": 1, "kind": "pour",
             "instruction": "Verter", "water_g": 205, "start_at_s": 45, "duration_s": null},
            {"id": "50000000-0000-0000-0000-000000000001", "position": 0, "kind": "bloom",
             "instruction": "Bloom", "water_g": 45, "start_at_s": 0, "duration_s": 45}
          ]
        }
        """
        let recipe = try decoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertEqual(recipe.method?.category, .pourOver)
        XCTAssertEqual(recipe.steps.map(\.kind), [.bloom, .pour])
        XCTAssertEqual(recipe.visibility, .public)
    }

    func testRecipeEncodingOmitsReadOnlyFields() throws {
        let recipe = Recipe(ownerID: UUID(), title: "Test", brewMethodID: UUID(), steps: [RecipeStep()])
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any]
        let keys = Set(object?.keys.map { $0 } ?? [])
        XCTAssertFalse(keys.contains("ratio"), "ratio es una columna generada")
        XCTAssertFalse(keys.contains("steps"))
        XCTAssertFalse(keys.contains("method"))
        XCTAssertTrue(keys.contains("dose_g"))
    }

    func testCalendarDayRoundTripKeepsLocalDay() throws {
        let day = CalendarDay(Date(timeIntervalSince1970: 1_790_000_000))
        let data = try JSONEncoder().encode(day)
        let decoded = try JSONDecoder().decode(CalendarDay.self, from: data)
        XCTAssertEqual(decoded, day)
    }

    func testVisibilityOrdering() {
        XCTAssertLessThan(Visibility.private, .followers)
        XCTAssertLessThan(Visibility.followers, .public)
    }
}
