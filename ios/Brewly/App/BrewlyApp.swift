import BrewlyData
import BrewlyDomain
import BrewlyFeatures
import SwiftUI

@main
struct BrewlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let dependencies = AppConfiguration.makeDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .onAppear { appDelegate.dependencies = dependencies }
        }
    }
}

enum AppConfiguration {
    /// Lee la URL y la clave pública (anon) de Supabase desde Info.plist, que a su
    /// vez las toma de `Config/Secrets.xcconfig` (no versionado).
    static func makeDependencies() -> AppDependencies {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString), url.host != nil,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            // Sin configuración se usa el backend en memoria para poder explorar la UI.
            return PreviewBackend.dependencies
        }
        return SupabaseEnvironment.makeDependencies(url: url, anonKey: key)
    }
}
