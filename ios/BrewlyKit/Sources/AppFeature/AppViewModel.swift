import BrewlyDomain
import Observation

/// Decides whether the user sees the sign-in screen or the app.
@MainActor
@Observable
final class AppViewModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn(UserProfile)
    }

    private(set) var phase: Phase = .launching
    private let container: AppContainer
    private var isObservingSession = false

    init(container: AppContainer) {
        self.container = container
    }

    /// Restores a stored session, if any, and starts listening for expirations.
    func start() async {
        observeSessionExpiration()
        guard await container.auth.hasStoredSession() else {
            phase = .signedOut
            return
        }
        do {
            phase = .signedIn(try await container.profile.currentUser())
        } catch DomainError.offline {
            // Keep the user signed in offline? Without a profile we can't build the UI yet.
            phase = .signedOut
        } catch {
            await container.auth.signOut()
            phase = .signedOut
        }
    }

    func didSignIn(_ user: UserProfile) {
        phase = .signedIn(user)
    }

    func didSignOut() {
        phase = .signedOut
    }

    private func observeSessionExpiration() {
        guard !isObservingSession else { return }
        isObservingSession = true
        let expirations = container.session.sessionExpired
        Task { [weak self] in
            for await _ in expirations {
                self?.phase = .signedOut
            }
        }
    }
}
