import BrewlyAPI
import Foundation
import JWT

/// Uses only the provider's trusted JWKS, separately from Brewly's access-token key collection.
enum ProviderTokenVerifier {
    static func verify(
        _ token: String, provider: IdentityProvider, keys: JWTKeyCollection,
        clientID: String
    ) async throws -> VerifiedIdentity {
        do {
            switch provider {
            case .apple:
                let claims = try await keys.verify(token, as: AppleIdentityToken.self)
                try claims.audience.verifyIntendedAudience(includes: clientID)
                guard let nonce = claims.nonce, !nonce.isEmpty, !claims.subject.value.isEmpty,
                    claims.issuedAt.value <= Date().addingTimeInterval(60)
                else { throw AppError.invalidCredentials }
                let email = claims.emailVerified?.value == true ? claims.email.map(AccountRules.normalize) : nil
                return VerifiedIdentity(provider: .apple, subject: claims.subject.value, email: email, nonce: nonce)
            case .google:
                let claims = try await keys.verify(token, as: GoogleIdentityToken.self)
                try claims.audience.verifyIntendedAudience(includes: clientID)
                guard let nonce = claims.nonce, !nonce.isEmpty, !claims.subject.value.isEmpty,
                    claims.issuedAt.value <= Date().addingTimeInterval(60)
                else { throw AppError.invalidCredentials }
                let email = claims.emailVerified?.value == true ? claims.email.map(AccountRules.normalize) : nil
                return VerifiedIdentity(
                    provider: .google, subject: claims.subject.value, email: email,
                    nonce: nonce, firstName: claims.givenName, lastName: claims.familyName)
            }
        } catch {
            throw AppError.invalidCredentials
        }
    }
}
