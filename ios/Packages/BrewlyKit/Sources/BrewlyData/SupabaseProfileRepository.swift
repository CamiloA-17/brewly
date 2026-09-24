import BrewlyDomain
import Foundation
import Supabase

struct SupabaseProfileRepository: ProfileRepository {
    let client: SupabaseClient

    private let select = "*, viewer_follow_status"

    func profile(id: UUID) async throws -> Profile {
        try await client.from("profiles")
            .select(select)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func profile(username: String) async throws -> Profile? {
        let result: [Profile] = try await client.from("profiles")
            .select(select)
            .eq("username", value: username.lowercased())
            .limit(1)
            .execute()
            .value
        return result.first
    }

    func search(_ query: String) async throws -> [Profile] {
        let term = query.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: " ")
        guard !term.isEmpty else { return [] }
        return try await client.from("profiles")
            .select(select)
            .or("username.ilike.%\(term)%,display_name.ilike.%\(term)%")
            .order("followers_count", ascending: false)
            .limit(25)
            .execute()
            .value
    }

    func updateMyProfile(_ update: ProfileUpdate) async throws -> Profile {
        let id = try client.requireUserID()
        return try await client.from("profiles")
            .update(update)
            .eq("id", value: id)
            .select(select)
            .single()
            .execute()
            .value
    }

    func uploadAvatar(_ jpegData: Data) async throws -> String {
        let id = try client.requireUserID()
        // Nombre único para invalidar cachés de imagen al cambiar la foto.
        let path = "\(id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from("avatars").upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        struct AvatarUpdate: Encodable { let avatar_path: String }
        try await client.from("profiles")
            .update(AvatarUpdate(avatar_path: path))
            .eq("id", value: id)
            .execute()
        return path
    }

    func publicAvatarURL(path: String) -> URL? {
        try? client.storage.from("avatars").getPublicURL(path: path)
    }
}
