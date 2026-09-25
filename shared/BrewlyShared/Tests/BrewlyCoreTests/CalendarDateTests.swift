import BrewlyCore
import Foundation
import Testing

@Suite("CalendarDate")
struct CalendarDateTests {
    @Test("Parses and formats ISO dates")
    func roundTrip() throws {
        let date = try #require(CalendarDate(isoString: "2026-09-05"))
        #expect(date.year == 2026 && date.month == 9 && date.day == 5)
        #expect(date.isoString == "2026-09-05")
    }

    @Test("Rejects invalid dates", arguments: ["2026-02-30", "2026-13-01", "26-01-01", "2026/01/01", ""])
    func rejectsInvalid(_ value: String) {
        #expect(CalendarDate(isoString: value) == nil)
    }

    @Test("Encodes as a JSON string")
    func codable() throws {
        let date = try #require(CalendarDate(year: 2025, month: 12, day: 1))
        let data = try JSONEncoder().encode([date])
        #expect(String(decoding: data, as: UTF8.self) == #"["2025-12-01"]"#)
        #expect(try JSONDecoder().decode([CalendarDate].self, from: data) == [date])
    }

    @Test("Counts days between dates")
    func daysBetween() throws {
        let roast = try #require(CalendarDate(isoString: "2026-02-20"))
        let brew = try #require(CalendarDate(isoString: "2026-03-02"))
        #expect(roast.days(until: brew) == 10)
        #expect(roast < brew)
    }
}
