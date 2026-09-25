# ADR 0002: SQL-first PostgreSQL schema with dbmate

- Status: accepted
- Date: 2026-09-25

## Context

The data model is relational and integrity matters (a recipe must use its author's bean; ratios
must match their inputs). ORM-managed migrations hide PostgreSQL features and tie the schema
to one backend language.

## Decision

- The schema lives in plain SQL migrations managed by **dbmate** (`database/migrations`).
- The server uses Fluent only for configuration and pooling and writes **explicit SQL** with
  SQLKit in repositories. There are no Fluent models or migrations.
- Integrity is enforced in the database: foreign keys (including composite ones for ownership),
  CHECK constraints, DOMAINs, generated columns and the `can_view_content` function.
- Global **catalogs** (brew methods, varietals, processes, countries, grinders, flavor notes) are
  reference data seeded by migrations and keyed by stable slugs.

## Consequences

- Any client or tool that talks to the database gets the same guarantees.
- Queries are explicit and easy to reason about; there is a little more mapping code.
- Every migration needs a `down` section; CI rolls all migrations back and applies them again.
- Enumerations are duplicated as Swift enums in `BrewlyCore`; they must change together.
