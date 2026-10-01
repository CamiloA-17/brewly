import Crypto
import JWT
import Vapor

struct AppleAuthConfig: Sendable {
    let clientID: String
    let teamID: String
    let keyID: String
    let privateKey: ES256PrivateKey
    let encryptionKey: SymmetricKey

    static func load() throws -> AppleAuthConfig? {
        guard let clientID = Environment.get("APPLE_CLIENT_ID"), !clientID.isEmpty else { return nil }
        guard let teamID = Environment.get("APPLE_TEAM_ID"), !teamID.isEmpty,
            let keyID = Environment.get("APPLE_KEY_ID"), !keyID.isEmpty,
            let encodedPEM = Environment.get("APPLE_PRIVATE_KEY_BASE64"),
            let pemData = Data(base64Encoded: encodedPEM), let pem = String(data: pemData, encoding: .utf8),
            let encodedKey = Environment.get("APPLE_TOKEN_ENCRYPTION_KEY"),
            let key = Data(base64Encoded: encodedKey), key.count == 32
        else {
            throw ConfigurationError(
                "Apple sign-in requires its team, key ID, base64 PEM key and a 32-byte base64 encryption key.")
        }
        return AppleAuthConfig(
            clientID: clientID, teamID: teamID, keyID: keyID,
            privateKey: try ES256PrivateKey(pem: pem), encryptionKey: SymmetricKey(data: key))
    }
}

/// Versioned authenticated encryption. Keep this key stable when rotating JWT_SECRET.
struct ProviderTokenCipher: Sendable {
    let key: SymmetricKey

    func encrypt(_ token: String) throws -> String {
        let box = try AES.GCM.seal(Data(token.utf8), using: key)
        guard let combined = box.combined else { throw AppError.unauthorized }
        return "v1:" + combined.base64EncodedString()
    }

    func decrypt(_ encrypted: String) throws -> String {
        guard encrypted.hasPrefix("v1:"), let data = Data(base64Encoded: String(encrypted.dropFirst(3))) else {
            throw AppError.unauthorized
        }
        let bytes = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
        guard let token = String(data: bytes, encoding: .utf8) else { throw AppError.unauthorized }
        return token
    }
}
