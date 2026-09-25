# ADR 0004: JWT access tokens with rotating refresh tokens

- Status: accepted
- Date: 2026-09-25

## Context

The app needs long-lived sessions without keeping a long-lived bearer token on the device.

## Decision

- Access tokens are **JWTs (HS256) valid for 15 minutes**, sent as `Authorization: Bearer`.
- Refresh tokens are **opaque random values valid for 30 days**, stored only as SHA-256 hashes,
  **single use** and rotated on every refresh. Reusing a consumed refresh token revokes all of
  the user's sessions.
- Identities live in `auth_identities` (`password` today, `apple` next), so Sign in with Apple
  can be added without schema changes.
- The app keeps tokens in the Keychain; `SessionManager` refreshes them transparently and
  serializes concurrent refreshes.

## Consequences

- A stolen access token is useful for minutes; a stolen refresh token is detected on reuse.
- Logging out and deleting the account revoke sessions immediately on the server.
