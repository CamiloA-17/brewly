import BrewlyDesignSystem
import BrewlyDomain
import Foundation
import Observation

@MainActor
@Observable
final class ComposePostViewModel {
    /// What the post shares besides text and photos.
    enum Attachment: Hashable {
        case none
        case recipe
        case bean
    }

    var draft = PostDraft()
    private(set) var attachment: Attachment = .none
    private(set) var myRecipes: [RecipeSummary] = []
    private(set) var myBeans: [Bean] = []
    private(set) var violations: [RuleViolation] = []
    private(set) var errorMessage: String?
    private(set) var isPublishing = false

    private let dependencies: FeedDependencies

    init(dependencies: FeedDependencies) {
        self.dependencies = dependencies
    }

    var canPublish: Bool {
        !isPublishing && draft.violations.isEmpty
    }

    /// Loads the user's recipes and beans so one can be shared.
    func load() async {
        async let recipes = dependencies.recipes.myRecipes(cursor: nil)
        async let beans = dependencies.beans.myBeans(includeArchived: false)
        myRecipes = (try? await recipes)?.items ?? []
        myBeans = (try? await beans) ?? []
    }

    func setPhotos(_ photos: [Data]) {
        draft.photos = Array(photos.prefix(PostRules.maxPhotos))
    }

    /// Publishes the post. Returns it on success.
    func publish() async -> Post? {
        violations = draft.violations
        guard violations.isEmpty else { return nil }
        isPublishing = true
        defer { isPublishing = false }
        do {
            let post = try await dependencies.posts.create(draft)
            errorMessage = nil
            return post
        } catch let DomainError.validation(violations) {
            self.violations = violations
        } catch {
            errorMessage = error.brewlyMessage
        }
        return nil
    }

    /// Chooses what to share, preselecting the user's newest recipe or first bean.
    func select(_ attachment: Attachment) {
        self.attachment = attachment
        switch attachment {
        case .none:
            draft.recipeID = nil
            draft.beanID = nil
        case .recipe:
            draft.beanID = nil
            if draft.recipeID == nil { draft.recipeID = myRecipes.first?.id }
        case .bean:
            draft.recipeID = nil
            if draft.beanID == nil { draft.beanID = myBeans.first?.id }
        }
    }
}
