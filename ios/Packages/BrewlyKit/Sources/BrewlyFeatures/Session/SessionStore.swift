import BrewlyDomain
import Observation
import SwiftUI

/// Estado global de la sesión: quién está autenticado y su perfil.
@MainActor
@Observable
public final class SessionStore {
    public private(set) var state: AuthState = .loading
    public private(set) var currentProfile: Profile?

    let dependencies: AppDependencies
    @ObservationIgnored private var listener: Task<Void, Never>?

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var currentUserID: UUID? {
        if case .signedIn(let id) = state { return id }
        return nil
    }

    public func start() {
        guard listener == nil else { return }
        listener = Task { [weak self, dependencies = self.dependencies] in
            for await state in dependencies.auth.authStates() {
                guard let self else { return }
                self.state = state
                if case .signedIn(let id) = state {
                    await self.loadProfile(id: id)
                    await self.registerStoredPushToken()
                } else {
                    self.currentProfile = nil
                }
            }
        }
    }

    public func loadProfile(id: UUID? = nil) async {
        guard let id = id ?? currentUserID else { return }
        currentProfile = try? await dependencies.profiles.profile(id: id)
    }

    public static let pushTokenDefaultsKey = "brewly.apnsToken"

    /// Asocia el token APNs del dispositivo al usuario que acaba de iniciar sesión.
    private func registerStoredPushToken() async {
        guard let token = UserDefaults.standard.string(forKey: Self.pushTokenDefaultsKey) else { return }
        try? await dependencies.notifications.registerPushToken(token)
    }

    public func updateProfile(_ profile: Profile) {
        currentProfile = profile
    }

    public func signOut() async {
        try? await dependencies.auth.signOut()
    }
}

// MARK: - Inyección por Environment

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies = PreviewBackend.dependencies
}

extension EnvironmentValues {
    public var dependencies: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}
