@preconcurrency import AuthenticationServices
import BrewlyDomain
import GoogleSignIn
import UIKit

/// Native provider flows. Only Brewly keeps session tokens after authentication.
@MainActor
public final class NativeProviderAuthorizer: NSObject, ProviderAuthorizing,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<ProviderCredential, any Error>?
    private var controller: ASAuthorizationController?
    private var window: UIWindow?

    public override init() { super.init() }

    public func authorize(provider: IdentityProvider, nonce: String) async throws -> ProviderCredential {
        guard
            let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow)
        else {
            throw DomainError.authenticationUnavailable
        }
        switch provider {
        case .apple:
            guard configuredString("BrewlyAppleSignInEnabled") == "YES" else {
                throw DomainError.authenticationUnavailable
            }
            guard continuation == nil else { throw DomainError.authenticationUnavailable }
            self.window = window
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = nonce
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let controller = ASAuthorizationController(authorizationRequests: [request])
                self.controller = controller
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        case .google:
            guard let clientID = configuredString("GIDClientID"),
                let serverClientID = configuredString("GIDServerClientID"),
                let schemes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
                schemes.contains(where: {
                    ($0["CFBundleURLSchemes"] as? [String])?.contains(
                        clientID.split(separator: ".").reversed().joined(separator: ".")) == true
                }),
                var presenter = window.rootViewController
            else { throw DomainError.authenticationUnavailable }
            while let presented = presenter.presentedViewController { presenter = presented }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: clientID, serverClientID: serverClientID)
            // Avoid keeping a second session in the provider SDK after copying its ID token.
            defer { GIDSignIn.sharedInstance.signOut() }
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenter, hint: nil, additionalScopes: nil, nonce: nonce)
                guard let token = result.user.idToken?.tokenString else { throw DomainError.unauthorized }
                return ProviderCredential(identityToken: token)
            } catch {
                let nsError = error as NSError
                if nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.canceled.rawValue {
                    throw DomainError.signInCancelled
                }
                throw error
            }
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
            let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8)
        else {
            finish(.failure(DomainError.unauthorized))
            return
        }
        finish(
            .success(
                ProviderCredential(
                    identityToken: token, authorizationCode: code,
                    firstName: credential.fullName?.givenName, lastName: credential.fullName?.familyName)))
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        let nsError = error as NSError
        finish(
            .failure(
                nsError.domain == ASAuthorizationError.errorDomain
                    && nsError.code == ASAuthorizationError.canceled.rawValue
                    ? DomainError.signInCancelled : error))
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // A foreground window is retained for the lifetime of the authorization request.
        window!
    }

    private func finish(_ result: Result<ProviderCredential, any Error>) {
        let pending = continuation
        continuation = nil
        controller = nil
        window = nil
        pending?.resume(with: result)
    }

    private func configuredString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty, !value.contains("$(")
        else { return nil }
        return value
    }

    public static func handle(url: URL) {
        _ = GIDSignIn.sharedInstance.handle(url)
    }
}
