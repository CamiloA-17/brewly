import SwiftUI
import UIKit

/// The user's choice of light or dark mode. `system` follows the device setting.
public enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    /// `UserDefaults` key used with `@AppStorage`. The choice is kept per device.
    public static let storageKey = "appearance"

    public var id: String { rawValue }

    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    public var localizedName: String {
        switch self {
        case .system: String(localized: "System", table: "Appearance", bundle: .module)
        case .light: String(localized: "Light", table: "Appearance", bundle: .module)
        case .dark: String(localized: "Dark", table: "Appearance", bundle: .module)
        }
    }

    public var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

public extension View {
    /// Applies the stored `AppearancePreference` to every window of the app.
    ///
    /// The style is set on the windows instead of with `preferredColorScheme`, so sheets,
    /// alerts and menus follow it too, and going back to `system` takes effect immediately.
    func brewlyAppearance() -> some View {
        modifier(AppearanceModifier())
    }
}

private struct AppearanceModifier: ViewModifier {
    @AppStorage(AppearancePreference.storageKey) private var preference: AppearancePreference = .system

    func body(content: Content) -> some View {
        content
            .task { apply(preference) }
            .onChange(of: preference) { _, newValue in apply(newValue) }
    }

    @MainActor
    private func apply(_ preference: AppearancePreference) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = preference.userInterfaceStyle
            }
        }
    }
}

/// Picker for the appearance preference, e.g. in a settings screen.
public struct AppearancePicker: View {
    @AppStorage(AppearancePreference.storageKey) private var preference: AppearancePreference = .system

    public init() {}

    public var body: some View {
        Picker(selection: $preference) {
            ForEach(AppearancePreference.allCases) { option in
                Label(option.localizedName, systemImage: option.systemImage).tag(option)
            }
        } label: {
            Text("Appearance", tableName: "Appearance", bundle: .module)
        }
    }
}
