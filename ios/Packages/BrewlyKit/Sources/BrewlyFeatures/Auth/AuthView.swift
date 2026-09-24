import AuthenticationServices
import BrewlyDomain
import CryptoKit
import SwiftUI

struct AuthView: View {
    @Environment(\.dependencies) private var dependencies

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var nonce = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(BrewlyTheme.crema)
                        Text("Brewly").font(.largeTitle.bold())
                        Text("Tu barra de café, tus recetas y tu comunidad.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    SignInWithAppleButton(isSignUp ? .signUp : .signIn) { request in
                        nonce = Self.randomNonce()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = Self.sha256(nonce)
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .frame(height: 48)
                    .listRowInsets(EdgeInsets())
                }

                Section(isSignUp ? "Crear cuenta con correo" : "Entrar con correo") {
                    if isSignUp {
                        TextField("Nombre de usuario", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    TextField("Correo", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Contraseña", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)

                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text(isSignUp ? "Crear cuenta" : "Entrar")
                        }
                    }
                    .disabled(!canSubmit || isWorking)
                }

                Section {
                    Button(isSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿Eres nuevo? Crea una cuenta") {
                        isSignUp.toggle()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 8
            && (!isSignUp || username.range(of: "^[a-z0-9_.]{3,30}$", options: .regularExpression) != nil)
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            if isSignUp {
                try await dependencies.auth.signUp(email: email, password: password, username: username)
            } else {
                try await dependencies.auth.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else { throw BrewlyError.validation("No se pudo leer la credencial de Apple.") }
            try await dependencies.auth.signInWithApple(idToken: idToken, nonce: nonce)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
