# ADR 0009: Native Apple and Google authentication

- Status: accepted
- Date: 2026-10-01

## Context

Members should be able to create and return to their private brewing account with Apple or
Google, while retaining the session lifecycle and required personal-details onboarding.

## Decision

- Use AuthenticationServices for Apple and Google's official iOS SDK for Google. Provider
  SDKs stay in BrewlyData and branded controls in BrewlyDesignSystem.
- The API verifies signatures against the provider JWKS and requires its configured audience,
  issuer, unexpired token and server-issued nonce. Provider keys remain separate from Brewly's
  HS256 access-token keys. Challenges live in PostgreSQL and are consumed atomically, so replay
  protection works across API instances.
- Find users by `(provider, subject)`, never by an unverified client email or matching email.
  Reject a new identity whose verified email belongs to another account. Account linking is
  a separate future authenticated operation requiring proof of both identities.
- Generate a unique username for new members, keep onboarding incomplete, and use the existing
  name, birth date, minimum age and accepted-terms flow. Provider names are initial hints only.
- Exchange Apple authorization codes on the API, verify the exchanged token belongs to the
  same subject and nonce, and store its refresh token with AES-GCM authenticated encryption.
  A dedicated 256-bit key is independent of JWT_SECRET. Revoke Apple authorization before
  local account deletion; preserve local data when revocation fails.
- Use Brewly's existing access and refresh tokens for every provider. Google SDK credentials
  are cleared after copying the ID token; no Google API access or offline grant is requested.

## Consequences

Provider configuration is optional in development: a disabled provider returns a stable 503
error, while email/password continues working. Apple requires a Developer capability, signing
key and stable encryption key; Google requires iOS and server OAuth client IDs and its callback
scheme. New Google members cannot cause a migration rollback to discard their identities:
rolling back Google support fails while those identities exist. Deleting an Apple account
requires Apple availability as well as PostgreSQL availability.
