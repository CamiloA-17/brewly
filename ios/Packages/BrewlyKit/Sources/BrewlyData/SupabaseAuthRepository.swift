import BrewlyDomain
import Foundation
import Supabase

struct SupabaseAuthRepository: AuthRepository {
    let client: SupabaseClient

    var currentUserID: UUID? {
        get async { try? await client.auth.session.user.id }
    }

    func authStates() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            let task = Task {
                // El primer evento (`initialSession`) refleja la sesión guardada en el llavero.
                for await (_, session) in client.auth.authStateChanges {
                    if let session, !session.isExpired {
                        continuation.yield(.signedIn(userID: session.user.id))
                    } else {
                        continuation.yield(.signedOut)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, username: String) async throws {
        // El trigger `handle_new_user` crea el perfil con este username.
        try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username.lowercased())]
        )
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
