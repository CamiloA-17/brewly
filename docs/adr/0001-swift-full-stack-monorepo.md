# ADR 0001: Swift full-stack monorepo

- Status: accepted
- Date: 2026-09-25

## Context

Brewly is a native iOS app (Swift) that needs a backend in front of a relational PostgreSQL
database. The options considered were Vapor (Swift), Supabase (managed PostgreSQL with
auto-generated APIs) and Node.js (NestJS).

## Decision

Build the API with **Vapor** and keep the app, the server, the database and a **shared Swift
package** (`BrewlyShared`) in one repository.

## Consequences

- One language end to end. DTOs and validation rules are written once and compiled by both the
  app and the server, so they cannot drift.
- Full control over business rules (ownership, visibility, feed ranking, moderation) with
  ordinary Swift code and tests.
- We own more infrastructure than with Supabase: authentication, file storage and hosting.
- The API contract is versioned (`/v1`) because older app versions keep running in the wild.
