import SwiftUI

/// Screens that any feature can link to without importing the feature that shows them.
///
/// Features push a route with `NavigationLink(value: AppRoute.member(id))`; `AppFeature`
/// decides which view each route opens and provides it through `routeDestinations`.
public enum AppRoute: Hashable, Sendable {
    case member(UUID)
    case recipe(UUID)
    case post(UUID)
    case memberSearch
    case followers(of: UUID)
    case following(of: UUID)
    case notifications
}

/// Builds the view for each `AppRoute`.
public struct RouteDestinations: Sendable {
    private let build: @MainActor @Sendable (AppRoute) -> AnyView

    public init(_ build: @escaping @MainActor @Sendable (AppRoute) -> AnyView) {
        self.build = build
    }

    @MainActor
    public func view(for route: AppRoute) -> AnyView {
        build(route)
    }

    /// Used when no destinations were provided (previews and tests).
    public static let none = RouteDestinations { _ in AnyView(EmptyView()) }
}

private struct RouteDestinationsKey: EnvironmentKey {
    static let defaultValue = RouteDestinations.none
}

public extension EnvironmentValues {
    var routeDestinations: RouteDestinations {
        get { self[RouteDestinationsKey.self] }
        set { self[RouteDestinationsKey.self] = newValue }
    }
}

public extension View {
    /// Registers the `AppRoute` destinations. Call it once on the root view of each `NavigationStack`.
    func appRouteDestinations() -> some View {
        modifier(AppRouteDestinationsModifier())
    }
}

private struct AppRouteDestinationsModifier: ViewModifier {
    @Environment(\.routeDestinations) private var destinations

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            destinations.view(for: route)
        }
    }
}
