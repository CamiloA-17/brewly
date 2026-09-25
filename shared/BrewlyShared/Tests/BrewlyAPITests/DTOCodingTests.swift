import BrewlyAPI
import Foundation
import Testing

@Suite("DTO coding")
struct DTOCodingTests {
    @Test("Recipe requests use camelCase keys and snake_case enum values")
    func recipeRequestJSON() throws {
        let request = UpsertRecipeRequest(
            beanId: UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!,
            methodSlug: "v60",
            title: "Floral V60",
            doseG: 15,
            waterG: 250,
            grindSize: .mediumFine,
            steps: [RecipeStepInput(kind: .bloom, startS: 0, waterTargetG: 45)]
        )
        let json = try #require(String(data: BrewlyJSON.makeEncoder().encode(request), encoding: .utf8))
        #expect(json.contains(#""grindSize":"medium_fine""#))
        #expect(json.contains(#""doseG":15"#))
        #expect(json.contains(#""visibility":"public""#))
        #expect(!json.contains("yieldG"))

        let decoded = try BrewlyJSON.makeDecoder().decode(UpsertRecipeRequest.self, from: Data(json.utf8))
        #expect(decoded == request)
        #expect(decoded.parameters.steps.first?.waterTargetG == 45)
    }

    @Test("Bean responses decode ISO dates and calendar dates")
    func beanResponseJSON() throws {
        let json = """
        {
          "id": "AAAAAAAA-0000-4000-8000-000000000001",
          "ownerId": "11111111-1111-4111-8111-111111111111",
          "name": "Geisha Washed",
          "countryCode": "CO",
          "varietalSlugs": ["geisha"],
          "flavorNoteSlugs": [],
          "roastLevel": "medium_light",
          "roastDate": "2026-09-10",
          "isDecaf": false,
          "visibility": "followers",
          "isArchived": false,
          "createdAt": "2026-09-25T10:00:00Z",
          "updatedAt": "2026-09-25T10:00:00Z"
        }
        """
        let bean = try BrewlyJSON.makeDecoder().decode(BeanDTO.self, from: Data(json.utf8))
        #expect(bean.roastLevel == .mediumLight)
        #expect(bean.roastDate == CalendarDate(year: 2026, month: 9, day: 10))
        #expect(bean.visibility == .followers)
        #expect(bean.createdAt == Date(timeIntervalSince1970: 1_790_330_400))
    }

    @Test("Remix fields are optional in requests and default to zero in counts")
    func socialFields() throws {
        let request = UpsertRecipeRequest(
            beanId: UUID(), forkedFromId: UUID(), methodSlug: "v60", title: "Remix", doseG: 15, waterG: 250,
            grindSize: .medium
        )
        let json = try #require(String(data: BrewlyJSON.makeEncoder().encode(request), encoding: .utf8))
        #expect(json.contains("forkedFromId"))

        let profile = UserProfileDTO(id: UUID(), username: "leo.roaster", displayName: "Leo", createdAt: Date())
        let decoded = try BrewlyJSON.makeDecoder().decode(
            UserProfileDTO.self, from: BrewlyJSON.makeEncoder().encode(profile)
        )
        #expect(decoded.summary == UserSummaryDTO(id: profile.id, username: "leo.roaster", displayName: "Leo"))
        #expect(decoded.followerCount == 0 && !decoded.isFollowing && !decoded.isMe)
    }

    @Test("Field errors are built from rule violations")
    func fieldErrors() {
        let error = APIErrorResponse.FieldError(RuleViolation(field: "doseG", kind: .outOfRange(min: 0.1, max: 1000)))
        #expect(error.code == "out_of_range")
        #expect(error.message == "Must be between 0.1 and 1000.")
    }
}
