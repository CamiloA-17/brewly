import BrewlyAPI
import Vapor

/// Image uploads, image downloads and the signed-in user's avatar.
struct MediaController: RouteCollection {
    /// Largest accepted upload; the app sends JPEGs of at most 1600 px, usually under 500 KB.
    static let maxUploadBytes = 2 * 1024 * 1024
    /// Uploads that are not used after this long are deleted on the owner's next upload.
    static let unusedUploadLifetime: TimeInterval = 24 * 60 * 60

    func boot(routes: any RoutesBuilder) throws {
        let media = routes.grouped("media")
        media.on(.POST, body: .collect(maxSize: ByteCount(value: Self.maxUploadBytes + 1024)), use: upload)
        media.get(":mediaID", use: download)
        routes.put("me", "avatar", use: setAvatar)
        routes.delete("me", "avatar", use: removeAvatar)
    }

    /// `POST /media` with a JPEG body (`Content-Type: image/jpeg`). Returns `MediaDTO` (201).
    @Sendable
    func upload(req: Request) async throws -> Response {
        let ownerID = try req.userID
        guard req.headers.contentType == .jpeg, let buffer = req.body.data else {
            throw AppError(status: .unsupportedMediaType, code: APIErrorCode.invalidImage, message: "Send a JPEG image.")
        }
        let jpeg = Data(buffer.readableBytesView)
        guard jpeg.count <= Self.maxUploadBytes else {
            throw AppError(status: .payloadTooLarge, code: APIErrorCode.payloadTooLarge, message: "Images can be at most 2 MB.")
        }
        guard let size = JPEGInfo.dimensions(of: jpeg), size.width <= 4096, size.height <= 4096 else {
            throw AppError(
                status: .unprocessableEntity, code: APIErrorCode.invalidImage,
                message: "The image is not a valid JPEG of at most 4096 × 4096 pixels."
            )
        }
        let repository = PostgresMediaRepository(database: req.db)
        try await repository.deleteUnusedUploads(ownerID: ownerID, olderThan: Self.unusedUploadLifetime)
        let media = try await repository.create(ownerID: ownerID, jpeg: jpeg, width: size.width, height: size.height)
        return try .json(media, status: .created)
    }

    /// `GET /media/{id}`: the image bytes. Images never change, so clients can cache them for good.
    @Sendable
    func download(req: Request) async throws -> Response {
        let id = try req.uuidParameter("mediaID", resource: "Image")
        let etag = "\"\(id.uuidString.lowercased())\""
        guard let data = try await PostgresMediaRepository(database: req.db).data(id: id, viewerID: try req.userID) else {
            throw AppError.notFound("Image")
        }
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .cacheControl, value: "private, max-age=31536000, immutable")
        headers.replaceOrAdd(name: .eTag, value: etag)
        if req.headers.first(name: .ifNoneMatch) == etag {
            return Response(status: .notModified, headers: headers)
        }
        headers.contentType = .jpeg
        return Response(status: .ok, headers: headers, body: .init(data: data))
    }

    /// `PUT /me/avatar` with `{ "mediaId": … }`: uses an uploaded image as the profile picture.
    @Sendable
    func setAvatar(req: Request) async throws -> Response {
        let body = try req.decodeJSON(UpdateAvatarRequest.self)
        let userID = try req.userID
        guard try await PostgresMediaRepository(database: req.db).setAvatar(userID: userID, mediaID: body.mediaId) else {
            throw AppError.unknownReference(field: "mediaId")
        }
        return try await currentUser(req, userID: userID)
    }

    /// `DELETE /me/avatar`: removes the profile picture.
    @Sendable
    func removeAvatar(req: Request) async throws -> Response {
        let userID = try req.userID
        _ = try await PostgresMediaRepository(database: req.db).setAvatar(userID: userID, mediaID: nil)
        return try await currentUser(req, userID: userID)
    }

    private func currentUser(_ req: Request, userID: UUID) async throws -> Response {
        guard let user = try await PostgresUserRepository(database: req.db).find(id: userID) else { throw AppError.unauthorized }
        return try .json(user)
    }
}
