import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class MemberProfileViewModel {
    private(set) var state: LoadState<MemberProfile> = .idle
    private(set) var catalog: Catalog = .empty
    private(set) var errorMessage: String?
    private(set) var isUpdatingFollow = false
    let recipes: Paginator<RecipeSummary>

    let memberID: UUID
    private let dependencies: PeopleDependencies

    init(memberID: UUID, dependencies: PeopleDependencies) {
        self.memberID = memberID
        self.dependencies = dependencies
        let people = dependencies.people
        recipes = Paginator { cursor in try await people.recipes(of: memberID, cursor: cursor) }
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            async let profile = dependencies.people.profile(id: memberID)
            async let catalog = dependencies.catalog.catalog()
            let (loadedProfile, loadedCatalog) = try await (profile, catalog)
            self.catalog = loadedCatalog
            state = .loaded(loadedProfile)
        } catch {
            if state.value == nil {
                state = .failed(error as? DomainError ?? .unexpected(String(describing: error)))
            }
            return
        }
        await recipes.load()
    }

    /// Follows or unfollows the member, updating the screen right away and reverting on failure.
    func toggleFollow() async {
        guard var profile = state.value, !profile.isMe, !isUpdatingFollow else { return }
        let original = profile
        let following = !profile.isFollowing
        profile.isFollowing = following
        profile.followerCount = max(0, profile.followerCount + (following ? 1 : -1))
        state = .loaded(profile)
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            let result = following
                ? try await dependencies.people.follow(memberID)
                : try await dependencies.people.unfollow(memberID)
            profile.isFollowing = result.isFollowing
            profile.followerCount = result.followerCount
            state = .loaded(profile)
            errorMessage = nil
        } catch {
            state = .loaded(original)
            errorMessage = error.brewlyMessage
            return
        }
        // Following can reveal followers-only recipes.
        await recipes.load()
    }
}
