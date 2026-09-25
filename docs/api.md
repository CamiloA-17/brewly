# API

Base URL: `http://localhost:8080` in development. Every endpoint except `/health` and
`/v1/auth/*` requires `Authorization: Bearer <access token>`.

The request and response types are Swift structs in
[`shared/BrewlyShared/Sources/BrewlyAPI`](../shared/BrewlyShared/Sources/BrewlyAPI), so the app
and the server always agree on the contract.

## Conventions

- JSON with `camelCase` keys; enumeration values are `snake_case` strings (`"medium_fine"`).
- Timestamps are ISO 8601 (`"2026-09-25T10:00:00Z"`); calendar days are `"YYYY-MM-DD"`.
- Catalog references are slugs (`"v60"`, `"washed"`) or ISO country codes (`"CO"`); the app loads
  `GET /v1/catalog` once and resolves names locally.
- Optional fields are omitted when empty.

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Liveness and database check. |
| POST | `/v1/auth/register` | Create an account. Returns `AuthResponse` (201). |
| POST | `/v1/auth/login` | Sign in with email and password. Returns `AuthResponse`. |
| POST | `/v1/auth/refresh` | Exchange a refresh token for a new token pair. |
| POST | `/v1/auth/logout` | Revoke a refresh token (204). |
| GET | `/v1/me` | The signed-in user's profile. |
| PATCH | `/v1/me` | Update display name, bio and location. |
| DELETE | `/v1/me` | Delete the account and all its data (204). |
| GET | `/v1/me/methods` | Slugs of the brew methods the user uses. |
| PUT | `/v1/me/methods/{slug}` | Mark a brew method as used (204, idempotent). |
| DELETE | `/v1/me/methods/{slug}` | Unmark a brew method (204). |
| GET | `/v1/catalog` | Every global catalog in one response. |
| GET | `/v1/me/beans?includeArchived=false` | The user's beans. |
| POST | `/v1/beans` | Create a bean (201). |
| GET | `/v1/beans/{id}` | A bean the user can see. |
| PUT | `/v1/beans/{id}` | Replace a bean the user owns (also archives it with `isArchived`). |
| DELETE | `/v1/beans/{id}` | Delete a bean; `409 bean_in_use` when recipes use it. |
| GET | `/v1/me/recipes?cursor=&limit=` | The user's recipes, newest first. |
| GET | `/v1/recipes?method=&country=&varietal=&cursor=&limit=` | Explore public recipes. |
| POST | `/v1/recipes` | Create a recipe (201). Set `forkedFromId` to remix a recipe the user can see. |
| GET | `/v1/recipes/{id}` | A recipe the user can see, with steps. |
| PUT | `/v1/recipes/{id}` | Replace a recipe the user wrote. |
| DELETE | `/v1/recipes/{id}` | Delete a recipe (204). |
| PUT | `/v1/recipes/{id}/save` | Save a recipe the user can see. Returns `SaveStateDTO` (idempotent). |
| DELETE | `/v1/recipes/{id}/save` | Remove a saved recipe. Returns `SaveStateDTO` (idempotent). |
| GET | `/v1/me/saved-recipes?cursor=&limit=` | Saved recipes, newest save first. |
| POST | `/v1/media` | Upload a JPEG (`Content-Type: image/jpeg`, at most 2 MB). Returns `MediaDTO` (201). |
| GET | `/v1/media/{id}` | Image bytes, if the user uploaded it or can see the post or avatar that uses it. Cacheable forever (`ETag`). |
| PUT | `/v1/me/avatar` | Use an uploaded image as profile picture (`{ "mediaId": … }`). Returns `CurrentUserDTO`. |
| DELETE | `/v1/me/avatar` | Remove the profile picture. Returns `CurrentUserDTO`. |
| GET | `/v1/feed?cursor=&limit=` | The user's posts and those of the people they follow, newest first. |
| GET | `/v1/posts/explore?cursor=&limit=` | Public posts of the community. |
| GET | `/v1/users/{id}/posts?cursor=&limit=` | The member's posts the user can see. |
| POST | `/v1/posts` | Publish a post with text, up to 4 uploaded images and optionally one own `recipeId` or `beanId` (201). |
| GET | `/v1/posts/{id}` | A post the user can see. |
| DELETE | `/v1/posts/{id}` | Delete a post the user wrote, with its images (204). |
| PUT | `/v1/posts/{id}/like` | Like a post. Returns `LikeStateDTO` (idempotent). |
| DELETE | `/v1/posts/{id}/like` | Remove a like. Returns `LikeStateDTO` (idempotent). |
| GET | `/v1/posts/{id}/comments?cursor=&limit=` | Comments, oldest first. |
| POST | `/v1/posts/{id}/comments` | Comment (`{ "body", "parentId"? }`); replies to a reply join its thread (201). |
| DELETE | `/v1/comments/{id}` | Delete a comment written by the user or on the user's post, with its replies (204). |
| GET | `/v1/me/notifications?cursor=&limit=` | Follows, likes, comments, replies, saves and remixes by other members, newest first (`NotificationDTO`). |
| GET | `/v1/me/notifications/unread-count` | `{ "count": … }` for the app's badge. |
| POST | `/v1/me/notifications/read` | Mark every notification as read (204). |
| GET | `/v1/users?q=` | Up to 20 members whose username or name starts with `q` (a leading `@` is ignored). |
| GET | `/v1/users/{id}` | A member's public profile with counts and follow state (`UserProfileDTO`). |
| GET | `/v1/users/{id}/recipes?cursor=&limit=` | The member's recipes the user can see. |
| GET | `/v1/users/{id}/followers?cursor=&limit=` | People who follow the member, newest first. |
| GET | `/v1/users/{id}/following?cursor=&limit=` | People the member follows, newest first. |
| PUT | `/v1/users/{id}/follow` | Follow a member. Returns `FollowStateDTO` (idempotent). |
| DELETE | `/v1/users/{id}/follow` | Unfollow a member. Returns `FollowStateDTO` (idempotent). |

## Examples

### Sign in

```http
POST /v1/auth/login
Content-Type: application/json

{ "email": "ana@example.com", "password": "<password>" }
```

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9…",
  "accessTokenExpiresAt": "2026-09-25T10:15:00Z",
  "refreshToken": "3yQ0…",
  "refreshTokenExpiresAt": "2026-10-25T10:00:00Z",
  "user": { "id": "1111…", "username": "ana.barista", "displayName": "Ana", "email": "ana@example.com", "createdAt": "2026-09-01T00:00:00Z" }
}
```

Refresh tokens are single use: `POST /v1/auth/refresh` returns a new pair and invalidates the old
refresh token. Reusing it revokes every session of the user.

### Create a recipe

```http
POST /v1/recipes
Authorization: Bearer <access token>
Content-Type: application/json

{
  "beanId": "aaaaaaaa-0000-4000-8000-000000000001",
  "methodSlug": "v60",
  "title": "Floral V60",
  "doseG": 15,
  "waterG": 250,
  "yieldG": 215,
  "grindSize": "medium_fine",
  "grinderSlug": "comandante_c40_mk4",
  "grindSetting": "24 clicks",
  "waterTempC": 93,
  "bloomWaterG": 45,
  "bloomTimeS": 45,
  "totalTimeS": 180,
  "filterType": "paper",
  "tdsPercent": 1.38,
  "rating": 5,
  "flavorNoteSlugs": ["jasmine", "peach"],
  "steps": [
    { "kind": "bloom", "startS": 0, "waterTargetG": 45, "instruction": "Bloom and swirl" },
    { "kind": "pour", "startS": 45, "waterTargetG": 250 }
  ],
  "visibility": "public"
}
```

The response is the full `RecipeDTO`, including `"ratio": 16.67` and
`"extractionYieldPercent": 19.78`, both computed by the database.

For espresso (`ratioBasis: "beverage"`), send `yieldG` (beverage weight) and omit `waterG`:
`{ "methodSlug": "espresso", "doseG": 18, "yieldG": 36, "grindSize": "fine", "pressureBar": 9, … }`
gives `"ratio": 2`.

### Publish a post with photos

Upload each photo first, then send the ids in the order they should appear:

```http
POST /v1/media
Content-Type: image/jpeg

<JPEG bytes>
```

```json
{ "id": "5f0c…", "url": "/v1/media/5f0c…", "width": 1600, "height": 1200 }
```

```http
POST /v1/posts
Content-Type: application/json

{ "body": "Dialing in a new natural", "mediaIds": ["5f0c…"], "recipeId": "bbbbbbbb-…", "visibility": "public" }
```

The server derives `kind` (`text`, `recipe` or `bean`) from what the post shares. If the shared
recipe or bean is not visible to a reader, the post still shows, without it. Image URLs are
relative to the API base URL and need the access token.

### Notifications

Notifications are created in the same transaction as the action. Nobody is notified about
their own actions or by blocked members, and a remix only notifies its original author when
they can see it. Follows, likes and saves notify once per member and target: undoing them
removes the notification, and doing them again doesn't notify twice. Deleting a comment removes
its notifications. `recipeId` is the saved recipe (`recipe_save`) or the new remix
(`recipe_fork`).

### Remix a recipe

A remix is a new recipe that starts from someone else's. The app copies the parameters, the
brewer picks one of their own beans, and the request carries the original's id:
`{ "forkedFromId": "bbbbbbbb-…", "beanId": "<own bean>", "methodSlug": "v60", … }`.
The response includes `forkedFrom` (id, title and author of the original) while the brewer can
still see it; the original's `forkCount` goes up by one. Deleting the original keeps the remix.

## Errors

Every non-2xx response has the same shape:

```json
{
  "code": "validation_failed",
  "message": "The request contains invalid fields.",
  "fieldErrors": [
    { "field": "yieldG", "code": "required", "message": "This field is required." },
    { "field": "steps[1].startS", "code": "out_of_range", "message": "Must be between 0 and 172800." }
  ]
}
```

| Status | Codes |
|---|---|
| 400 | `bad_request` (malformed JSON, invalid cursor) |
| 401 | `unauthorized`, `invalid_credentials` |
| 404 | `not_found` (also for content the user is not allowed to see, and for members who blocked the user or were blocked) |
| 409 | `username_taken`, `email_taken`, `bean_in_use`, `conflict` |
| 413 | `payload_too_large` (images over 2 MB) |
| 415 | `invalid_image` (uploads that are not `image/jpeg`) |
| 422 | `validation_failed` with `fieldErrors`, `cannot_follow_self`, `invalid_image` |
| 500 | `internal_error` |

Field error codes: `required`, `out_of_range`, `too_long`, `invalid_format`, `not_allowed`,
`exceeds`, `in_future`, `too_many`, `not_found` (unknown catalog slug or bean).

## Pagination

List endpoints return a page:

```json
{ "items": [ … ], "nextCursor": "eyJjcmVhdGVkQXQiOiIyMDI2…" }
```

Pass `nextCursor` back as `?cursor=` to get the next page; it is `null` on the last page.
`limit` defaults to 20 (maximum 50). Cursors are keyset-based on `(created_at, id)`, so pages
stay stable while new recipes are published.
