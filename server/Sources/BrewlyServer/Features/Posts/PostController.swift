import BrewlyAPI
import Vapor

/// Posts, the home feed, likes and comments.
struct PostController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("feed", use: feed)
        routes.get("users", ":userID", "posts", use: memberPosts)
        let posts = routes.grouped("posts")
        posts.get("explore", use: explore)
        posts.post(use: create)
        posts.get(":postID", use: show)
        posts.delete(":postID", use: delete)
        posts.put(":postID", "like", use: like)
        posts.delete(":postID", "like", use: unlike)
        posts.get(":postID", "comments", use: comments)
        posts.post(":postID", "comments", use: addComment)
        routes.delete("comments", ":commentID", use: deleteComment)
    }

    /// `GET /feed?cursor=&limit=`: the user's posts and those of the people they follow.
    @Sendable
    func feed(req: Request) async throws -> Response {
        try await list(req, scope: .feed)
    }

    /// `GET /posts/explore?cursor=&limit=`: public posts of the community.
    @Sendable
    func explore(req: Request) async throws -> Response {
        try await list(req, scope: .explore)
    }

    /// `GET /users/{id}/posts?cursor=&limit=`: the member's posts the user can see.
    @Sendable
    func memberPosts(req: Request) async throws -> Response {
        try await list(req, scope: .authoredBy(try req.uuidParameter("userID", resource: "User")))
    }

    @Sendable
    func create(req: Request) async throws -> Response {
        let post = try await service(req).create(authorID: try req.userID, try req.decodeJSON(CreatePostRequest.self))
        return try .json(post, status: .created)
    }

    @Sendable
    func show(req: Request) async throws -> Response {
        let id = try req.uuidParameter("postID", resource: "Post")
        return try .json(try await service(req).get(id: id, viewerID: try req.userID))
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("postID", resource: "Post")
        try await service(req).delete(id: id, authorID: try req.userID)
        return .noContent
    }

    /// `PUT /posts/{id}/like`: idempotent.
    @Sendable
    func like(req: Request) async throws -> Response {
        let id = try req.uuidParameter("postID", resource: "Post")
        return try .json(try await service(req).like(postID: id, userID: try req.userID))
    }

    /// `DELETE /posts/{id}/like`: idempotent.
    @Sendable
    func unlike(req: Request) async throws -> Response {
        let id = try req.uuidParameter("postID", resource: "Post")
        return try .json(try await service(req).unlike(postID: id, userID: try req.userID))
    }

    /// `GET /posts/{id}/comments?cursor=&limit=`: oldest first.
    @Sendable
    func comments(req: Request) async throws -> Response {
        let id = try req.uuidParameter("postID", resource: "Post")
        let page = try await service(req).comments(
            postID: id, viewerID: try req.userID, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    @Sendable
    func addComment(req: Request) async throws -> Response {
        let id = try req.uuidParameter("postID", resource: "Post")
        let comment = try await service(req).addComment(
            postID: id, authorID: try req.userID, try req.decodeJSON(CreateCommentRequest.self)
        )
        return try .json(comment, status: .created)
    }

    /// `DELETE /comments/{id}`: by its author or the author of the post.
    @Sendable
    func deleteComment(req: Request) async throws -> HTTPStatus {
        let id = try req.uuidParameter("commentID", resource: "Comment")
        try await service(req).deleteComment(id: id, userID: try req.userID)
        return .noContent
    }

    private func list(_ req: Request, scope: PostListScope) async throws -> Response {
        let page = try await service(req).list(
            scope: scope, viewerID: try req.userID, cursor: req.query[String.self, at: "cursor"], limit: req.pageLimit
        )
        return try .json(page)
    }

    private func service(_ req: Request) -> PostService {
        PostService(posts: PostgresPostRepository(database: req.db))
    }
}
