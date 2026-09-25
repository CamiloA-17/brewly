# ADR 0006: Store images in PostgreSQL

- Status: accepted
- Date: 2026-09-26

## Context

Posts can have photos and members can have a profile picture. The usual setup is object storage
(S3, R2) with presigned uploads, which adds a service, credentials and another piece to run
locally. At this stage the priority is a simple, cheap stack that is easy to run with
`docker compose`.

## Decision

- Images are stored as `bytea` in a `media` table, with the uploader as owner.
- The app resizes photos to at most 1600 px and sends JPEG (quality 0.8, usually under 500 KB);
  the API accepts `image/jpeg` up to 2 MB and 4096 × 4096 px, reading the size from the JPEG
  header.
- Uploading is a separate step (`POST /v1/media`); posts and avatars reference the returned id.
  Unused uploads are deleted after a day.
- Images are served by the API at `/v1/media/{id}` with the same visibility rules as the post
  or profile that uses them, and are cached by clients forever (images never change).

## Consequences

- No extra infrastructure, and deleting an account or post deletes its images in the same
  transaction.
- The database and its backups grow with the images, and the API serves the bytes. This is fine
  for early usage; when it isn't, images can move to object storage behind the same
  `/v1/media/{id}` URL (redirecting to a presigned URL), with no change in the app.
- Videos are out of scope.
