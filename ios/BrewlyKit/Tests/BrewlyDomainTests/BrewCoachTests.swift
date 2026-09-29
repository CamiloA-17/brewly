import BrewlyDomain
import Foundation
import Testing

@Suite("Brew coach")
struct BrewCoachTests {
    @Test func suggestsOneGrindChangeForAnAcidicCup() {
        let cup = session(rating: 2, acidity: 5, bitterness: 1)
        #expect(BrewCoach.suggestion(for: cup) == .tryFinerGrind)
    }

    @Test func doesNotGuessWithoutTasteFeedback() {
        #expect(BrewCoach.suggestion(for: session(rating: nil, acidity: nil, bitterness: nil)) == nil)
    }

    @Test func asksToRepeatAWellRatedCup() {
        #expect(BrewCoach.suggestion(for: session(rating: 5, acidity: 3, bitterness: 1)) == .repeatBest)
    }

    @Test func comparesAttemptsOfTheSameRecipe() {
        let previous = session(rating: 3, acidity: 3, bitterness: 2)
        var latest = previous
        latest.grindSetting = "22 clicks"
        latest.rating = 4
        let comparison = BrewCoach.compare(latest, with: previous)
        #expect(comparison?.changedVariables == ["grind"])
        #expect(comparison?.ratingChange == 1)
    }

    private func session(rating: Int?, acidity: Int?, bitterness: Int?) -> BrewSession {
        BrewSession(id: UUID(), recipeID: UUID(), recipeTitle: "V60", beanName: "Test bean",
                    methodSlug: "v60", doseG: 15, waterG: 250, yieldG: nil,
                    grindSetting: "24 clicks", waterTempC: 93, elapsedS: 180,
                    rating: rating, acidity: acidity, bitterness: bitterness,
                    body: nil, notes: nil, createdAt: .now)
    }
}
