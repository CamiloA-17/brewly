import BrewlyAPI
import Foundation
import Vapor

/// Rules for profiles of other members and the follow graph.
struct PeopleService: Sendable {
    let people: any PeopleRepository

    static let searchLimit = 20

    func profile(id: UUID, viewerID: UUID) async throws -> UserProfileDTO {
        guard let profile = try await people.profile(id: id, viewerID: viewerID) else { throw AppError.notFound("User") }
        return profile
    }

    /// An empty query returns no one; a leading "@" is ignored.
    func search(query: String?, viewerID: UUID) async throws -> [UserSummaryDTO] {
        let prefix = Self.normalizedQuery(query)
        guard !prefix.isEmpty else { return [] }
        return try await people.search(prefix: prefix, viewerID: viewerID, limit: Self.searchLimit)
    }

    func follows(of memberID: UUID, kind: FollowListKind, viewerID: UUID, cursor: String?, limit: Int)
        async throws -> BrewlyAPI.Page<UserSummaryDTO> {
        // Lists of hidden members are hidden too.
        _ = try await profile(id: memberID, viewerID: viewerID)
        return try await people.follows(
            of: memberID, kind: kind, viewerID: viewerID, after: try PageCursor.decodeParameter(cursor), limit: limit
        )
    }

    func follow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO {
        guard memberID != followerID else {
            throw AppError(status: .unprocessableEntity, code: APIErrorCode.cannotFollowSelf, message: "You can't follow yourself.")
        }
        guard let state = try await people.follow(memberID: memberID, followerID: followerID) else {
            throw AppError.notFound("User")
        }
        return state
    }

    func unfollow(memberID: UUID, followerID: UUID) async throws -> FollowStateDTO {
        try await people.unfollow(memberID: memberID, followerID: followerID)
    }

    static func normalizedQuery(_ query: String?) -> String {
        var text = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("@") { text.removeFirst() }
        return String(text.prefix(60))
    }
}
