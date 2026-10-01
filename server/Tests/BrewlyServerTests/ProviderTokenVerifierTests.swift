import BrewlyAPI
import Crypto
import JWT
import XCTest

@testable import BrewlyServer

final class ProviderTokenVerifierTests: XCTestCase {
    private func keys() async -> JWTKeyCollection {
        await JWTKeyCollection().add(ecdsa: ES256PrivateKey())
    }
    private func google(
        issuer: String = "https://accounts.google.com", audience: String = "google-client",
        expires: Date = Date().addingTimeInterval(300), nonce: String? = "server-nonce",
        verified: Bool = true
    ) -> GoogleIdentityToken {
        GoogleIdentityToken(
            issuer: .init(value: issuer), subject: "stable-google-subject",
            audience: .init(value: audience), authorizedPresenter: "ios-client",
            issuedAt: .init(value: Date()), expires: .init(value: expires), email: "ANA@example.com",
            emailVerified: .init(value: verified), givenName: "Ana", familyName: "Rojas", nonce: nonce)
    }

    func testGoogleVerifiesAndNormalizesEmail() async throws {
        let keys = await keys()
        let token = try await keys.sign(google())
        let identity = try await ProviderTokenVerifier.verify(
            token, provider: .google, keys: keys, clientID: "google-client")
        XCTAssertEqual(identity.subject, "stable-google-subject")
        XCTAssertEqual(identity.email, "ana@example.com")
        XCTAssertEqual(identity.firstName, "Ana")
        XCTAssertEqual(identity.nonce, "server-nonce")
    }

    func testRejectsWrongIssuerAudienceExpiredMissingNonceAndSignature() async throws {
        let keys = await keys()
        for claims in [
            google(issuer: "https://attacker.example.com"), google(audience: "another-app"),
            google(expires: Date().addingTimeInterval(-1)), google(nonce: nil),
        ] {
            let token = try await keys.sign(claims)
            do {
                _ = try await ProviderTokenVerifier.verify(
                    token, provider: .google, keys: keys, clientID: "google-client")
                XCTFail("Expected invalid credentials")
            } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
        }
        let untrusted = await self.keys()
        let forged = try await untrusted.sign(google())
        do {
            _ = try await ProviderTokenVerifier.verify(forged, provider: .google, keys: keys, clientID: "google-client")
            XCTFail("Expected signature rejection")
        } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
    }

    func testMalformedAndIncompleteSignedTokensAreAuthenticationErrors() async throws {
        let keys = await keys()
        let incomplete = try await keys.sign(IncompleteProviderClaims())
        for token in ["not-a-token", incomplete] {
            do {
                _ = try await ProviderTokenVerifier.verify(
                    token, provider: .google, keys: keys, clientID: "google-client")
                XCTFail("Expected malformed claims to be rejected")
            } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
        }
    }

    func testUnverifiedEmailCannotBecomeAnAccountEmail() async throws {
        let keys = await keys()
        let token = try await keys.sign(google(verified: false))
        let identity = try await ProviderTokenVerifier.verify(
            token, provider: .google, keys: keys, clientID: "google-client")
        XCTAssertNil(identity.email)
    }

    func testApplePrivateRelayAndAudience() async throws {
        let keys = await keys()
        let claims = AppleIdentityToken(
            issuer: "https://appleid.apple.com", audience: "app.brewly.ios",
            expires: .init(value: Date().addingTimeInterval(300)), issuedAt: .init(value: Date()),
            subject: "stable-apple-subject", nonce: "server-nonce", email: "relay@example.com",
            emailVerified: true, isPrivateEmail: true)
        let token = try await keys.sign(claims)
        let identity = try await ProviderTokenVerifier.verify(
            token, provider: .apple, keys: keys, clientID: "app.brewly.ios")
        XCTAssertEqual(identity.email, "relay@example.com")
        do {
            _ = try await ProviderTokenVerifier.verify(token, provider: .apple, keys: keys, clientID: "another-app")
            XCTFail("Expected audience rejection")
        } catch { XCTAssertEqual((error as? AppError)?.code, APIErrorCode.invalidCredentials) }
    }

    func testEncryptedProviderTokensRoundTripAndRejectTampering() throws {
        let cipher = ProviderTokenCipher(key: SymmetricKey(size: .bits256))
        let encrypted = try cipher.encrypt("provider-token")
        XCTAssertFalse(encrypted.contains("provider-token"))
        XCTAssertEqual(try cipher.decrypt(encrypted), "provider-token")
        XCTAssertNotEqual(encrypted, try cipher.encrypt("provider-token"))
        XCTAssertThrowsError(try cipher.decrypt("v1:" + Data(repeating: 0, count: 64).base64EncodedString()))
        XCTAssertThrowsError(try ProviderTokenCipher(key: SymmetricKey(size: .bits256)).decrypt(encrypted))
    }
}

private struct IncompleteProviderClaims: JWTPayload {
    var sub = "missing-required-claims"
    func verify(using algorithm: some JWTAlgorithm) async throws {}
}
