import AppFeature
import SwiftUI

@main
struct BrewlyApp: App {
    @State private var container = AppContainer(apiBaseURL: Self.apiBaseURL)

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }

    /// Read from Info.plist (`BREWLY_API_BASE_URL` build setting in project.yml).
    private static var apiBaseURL: URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "BrewlyAPIBaseURL") as? String,
              let url = URL(string: value)
        else {
            fatalError("BrewlyAPIBaseURL is missing from Info.plist.")
        }
        return url
    }
}
