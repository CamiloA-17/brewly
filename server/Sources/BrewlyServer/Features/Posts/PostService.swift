import BrewlyAPI
import Foundation
import PostgresNIO

/// Rules for posts, likes and comments.
struct PostService: Sendable {
    let posts: any PostRepository

    func list(scope: PostListScope, viewerID: UUID, cursor: String?, limit: Int) async throws -> BrewlyAPI.Page<PostDTO> {
        try await posts.list(scope: scope, viewerID: viewerID, after: try PageCursor.decodeParameter(cursor), limit: limit)
    }

    func get(id: UUID, viewerID: UUID) async throws -> PostDTO {
        guard let post = try await posts.find(id: id, viewerID: viewerID) else { throw AppError.notFound("Post") }
        return post
    }

    func create(authorID: UUID, _ request: CreatePostRequest) async throws -> PostDTO {
        let post = try validated(request)
        let kind = PostRules.kind(sharesRecipe: post.recipeId != nil, sharesBean: post.beanId != nil)
        do {
            return try await posts.create(authorID: authorID, kind: kind, post)
        } catch is UnavailableMediaError {
            throw AppError.unknownReference(field: "mediaIds")
        } catch let error as PSQLError where error.isForeignKeyViolation || error.isUniqueViolation {
            // Shared content must be the author's own; each image can only be in one post.
            let field = switch error.constraintName {
            case "posts_recipe_owned_by_author": "recipeId"
            case "posts_bean_owned_by_author": "beanId"
            case "post_media_media_key": "mediaIds"
            default: "unknown"
            }
            throw AppError.unknownReference(field: field)
        }
    }

    func delete(id: UUID, authorID: UUID) async throws {
        guard try await posts.delete(id: id, authorID: authorID) else { throw AppError.notFound("Post") }
    }

    func like(postID: UUID, userID: UUID) async throws -> LikeStateDTO {
        guard let state = try await posts.like(postID: postID, userID: userID) else { throw AppError.notFound("Post") }
        return state
    }

    func unlike(postID: UUID, userID: UUID) async throws -> LikeStateDTO {
        try await posts.unlike(postID: postID, userID: userID)
    }

    func comments(postID: UUID, viewerID: UUID, cursor: String?, limit: Int) async throws -> BrewlyAPI.Page<CommentDTO> {
        let page = try await posts.comments(
            postID: postID, viewerID: viewerID, after: try PageCursor.decodeParameter(cursor), limit: limit
        )
        guard let page else { throw AppError.notFound("Post") }
        return page
    }

    func addComment(postID: UUID, authorID: UUID, _ request: CreateCommentRequest) async throws -> CommentDTO {
        let violations = PostRules.validateComment(body: request.body)
        guard violations.isEmpty else { throw AppError.validation(violations) }
        do {
            let comment = try await posts.addComment(
                postID: postID, authorID: authorID, body: request.body.trimmingWhitespace, parentID: request.parentId
            )
            guard let comment else { throw AppError.notFound("Post") }
            return comment
        } catch is UnknownParentCommentError {
            throw AppError.unknownReference(field: "parentId")
        }
    }

    func deleteComment(id: UUID, userID: UUID) async throws {
        guard try await posts.deleteComment(id: id, userID: userID) else { throw AppError.notFound("Comment") }
    }

    /// Checks the post and normalizes its text; photos keep their order and repeated ids are rejected.
    func validated(_ request: CreatePostRequest) throws -> CreatePostRequest {
        var violations = PostRules.validatePost(
            body: request.body,
            sharesRecipe: request.recipeId != nil,
            sharesBean: request.beanId != nil,
            photoCount: request.mediaIds.count
        )
        if Set(request.mediaIds).count != request.mediaIds.count {
            violations.append(RuleViolation(field: "mediaIds", kind: .invalidFormat))
        }
        guard violations.isEmpty else { throw AppError.validation(violations) }
        var post = request
        post.body = request.body.nilIfBlank
        return post
    }
}
