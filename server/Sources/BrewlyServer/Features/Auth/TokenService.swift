import Crypto
import Foundation
import JWT

/// Issues JWT access tokens and opaque refresh tokens.
struct TokenService: Sendable {
    let keys: JWTKeyCollection
    let accessTokenTTL: TimeInterval
    let refreshTokenTTL: TimeInterval

    func makeAccessToken(userID: UUID, now: Date = Date()) async throws -> (token: String, expiresAt: Date) {
        let expiresAt = now.addingTimeInterval(accessTokenTTL)
        let payload = AccessTokenPayload(
            subject: SubjectClaim(value: userID.uuidString),
            expiration: ExpirationClaim(value: expiresAt),
            issuedAt: IssuedAtClaim(value: now)
        )
        return (try await keys.sign(payload), expiresAt)
    }

    func refreshTokenExpiry(now: Date = Date()) -> Date {
        now.addingTimeInterval(refreshTokenTTL)
    }

    /// 256 random bits, base64url-encoded. Only its hash is stored.
    static func makeRefreshToken() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Hex-encoded SHA-256 of a refresh token, as stored in `refresh_tokens.token_hash`.
    static func hash(refreshToken: String) -> String {
        SHA256.hash(data: Data(refreshToken.utf8))
            .map { byte in
                let hex = String(byte, radix: 16)
                return byte < 16 ? "0" + hex : hex
            }
            .joined()
    }
}
