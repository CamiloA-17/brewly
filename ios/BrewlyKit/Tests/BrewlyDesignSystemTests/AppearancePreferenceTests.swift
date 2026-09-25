@testable import BrewlyDesignSystem
import Testing
import UIKit

@Suite("AppearancePreference")
struct AppearancePreferenceTests {
    @Test("Each preference maps to a window style")
    func userInterfaceStyle() {
        #expect(AppearancePreference.system.userInterfaceStyle == .unspecified)
        #expect(AppearancePreference.light.userInterfaceStyle == .light)
        #expect(AppearancePreference.dark.userInterfaceStyle == .dark)
    }

    @Test("Stored values stay stable")
    func rawValues() {
        #expect(AppearancePreference.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(AppearancePreference(rawValue: "sepia") == nil)
    }

    @Test("Every preference has a name")
    func names() {
        for preference in AppearancePreference.allCases {
            #expect(!preference.localizedName.isEmpty)
        }
    }
}
