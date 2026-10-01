import BrewlyAPI
import Foundation
import Testing

@Suite("Federated auth DTOs")
struct FederatedAuthCodingTests {
    @Test("Both providers round-trip through challenge JSON")
    func challenges() throws {
        for provider in IdentityProvider.allCases {
            let request = AuthChallengeRequest(provider: provider)
            let data = try BrewlyJSON.makeEncoder().encode(request)
            #expect(try BrewlyJSON.makeDecoder().decode(AuthChallengeRequest.self, from: data) == request)
        }
    }

    @Test("Apple code and name hints are optional for Google")
    func credentials() throws {
        let id = UUID()
        let request = FederatedSignInRequest(challengeId: id, identityToken: "id-token")
        let data = try BrewlyJSON.makeEncoder().encode(request)
        #expect(try BrewlyJSON.makeDecoder().decode(FederatedSignInRequest.self, from: data) == request)
        let keys = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(keys["challengeId"] != nil)
        #expect(keys["authorizationCode"] == nil)
        #expect(keys["email"] == nil)
    }
}
