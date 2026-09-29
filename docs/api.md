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
| POST | `/v1/auth/register` | Create an account with first and last name, birth date (13 or older) and accepted terms. Returns `AuthResponse` (201). |
| POST | `/v1/auth/login` | Sign in with email and password. Returns `AuthResponse`. |
| POST | `/v1/auth/refresh` | Exchange a refresh token for a new token pair. |
| POST | `/v1/auth/logout` | Revoke a refresh token (204). |
| GET | `/v1/me` | The signed-in user's profile, with the private details (name, birth date). |
| PATCH | `/v1/me` | Update display name, bio, country, city (optional) and the private details. |
| PUT | `/v1/me/onboarding` | Fill in the private details of an account that has none (`needsOnboarding`). Returns `CurrentUserDTO`. |
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
| GET | `/v1/me/brew-sessions?recipeId=&cursor=&limit=` | The user's completed cups, newest first. Optionally filter by recipe. |
| POST | `/v1/me/brew-sessions` | Record a cup from one of the user's recipes (201). |
| POST | `/v1/recipes` | Create a private recipe plan (201). |
| GET | `/v1/recipes/{id}` | A recipe owned by the signed-in user, with steps. |
| PUT | `/v1/recipes/{id}` | Replace a recipe the user wrote. |
| DELETE | `/v1/recipes/{id}` | Delete a recipe (204). |
| POST | `/v1/media` | Upload a JPEG (`Content-Type: image/jpeg`, at most 2 MB). Returns `MediaDTO` (201). |
| GET | `/v1/media/{id}` | Image bytes, if the user uploaded it or it is a current avatar. Cacheable forever (`ETag`). |
| PUT | `/v1/me/avatar` | Use an uploaded image as profile picture (`{ "mediaId": … }`). Returns `CurrentUserDTO`. |
| DELETE | `/v1/me/avatar` | Remove the profile picture. Returns `CurrentUserDTO`. |

## Examples

### Record a cup

`POST /v1/me/brew-sessions` accepts `recipeId`, actual `doseG`, optional `waterG`,
`yieldG`, `grindSetting`, `waterTempC` and `tdsPercent`, elapsed seconds in `elapsedS`, optional
1–5 scores (`rating`, `acidity`, `bitterness`, `body`) and `notes`. The server snapshots
the recipe title, bean name and method. The response computes extraction yield when beverage
weight and TDS are supplied. Only the recipe owner can record a session;
sessions are visible only to their owner. Editing a recipe leaves prior sessions unchanged,
and deleting it retains the sessions with `recipeId: null`.

Feed, public profile, follow, post, comment, recipe discovery, save and activity notification
routes return 404. Requests containing a `forkedFromId` remix link return 422. Their former
development data and tables were removed.

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
  "user": {
    "id": "1111…", "username": "ana.barista", "displayName": "Ana Demo", "email": "ana@example.com",
    "firstName": "Ana", "lastName": "Demo", "birthDate": "1995-04-12", "countryCode": "CO", "city": "Bogotá",
    "needsOnboarding": false, "createdAt": "2026-09-01T00:00:00Z"
  }
}
```

Sign-up body: `email`, `password`, `username`, `firstName`, `lastName`, `birthDate` (`YYYY-MM-DD`),
`acceptedTerms` (must be `true`) and an optional `displayName`, which defaults to "First Last".
Members younger than 13 get a `too_young` field error on `birthDate`.

First name, last name and birth date are private: they are only returned by `/v1/me`. Public
profiles (`GET /v1/users/{id}`) show `countryCode` and `city`. When `needsOnboarding` is `true`
the app asks for the missing details with `PUT /v1/me/onboarding` before anything else.

Refresh tokens are single use: `POST /v1/auth/refresh` returns a new pair and invalidates the old
refresh token. Reusing it revokes every session of the user.

### Create a recipe plan

Recipes hold intended parameters and steps. Actual measurements and tasting results belong
to brew sessions. The recipe endpoint still accepts old result fields for client compatibility.

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
  "steps": [
    { "kind": "bloom", "startS": 0, "waterTargetG": 45, "instruction": "Bloom and swirl" },
    { "kind": "pour", "startS": 45, "waterTargetG": 250 }
  ],
  "visibility": "private"
}
```

The response is the full `RecipeDTO`, including the calculated `"ratio": 16.67`.

For espresso (`ratioBasis: "beverage"`), send `yieldG` (beverage weight) and omit `waterG`:
`{ "methodSlug": "espresso", "doseG": 18, "yieldG": 36, "grindSize": "fine", "pressureBar": 9, … }`
gives `"ratio": 2`.

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
| 404 | `not_found` (also for content the user is not allowed to see and retired social routes) |
| 409 | `username_taken`, `email_taken`, `bean_in_use`, `conflict` |
| 413 | `payload_too_large` (images over 2 MB) |
| 415 | `invalid_image` (uploads that are not `image/jpeg`) |
| 422 | `validation_failed` with `fieldErrors`, `invalid_image` |
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
stay stable while new recipes or brew sessions are created.
