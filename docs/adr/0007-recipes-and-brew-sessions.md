# ADR 0007: Separate recipe plans from actual brews

## Status

Accepted, 2026-09-28.

## Context

The original recipe model stored a reusable method and one cup's result in the same row.
Editing the recipe overwrote that result, making comparisons and learning from attempts
impossible. The app also led with a social feed even though the most useful data was a
user's own coffee, method and preparation history.

## Decision

Recipes remain preparation plans and keep their current identifiers. `brew_sessions` stores
each completed cup separately with a snapshot of its recipe title, bean name, method, actual
measurements, elapsed time and tasting scores. Shared validation rules keep the app and API
aligned. Sessions are private to their owner and remain
when a recipe is edited or deleted. A migration copies existing result-bearing recipes into
one historical session each. The app leads with brewing and removes the feed from navigation.

The initial transition retained social tables and recipe discovery compatibility until the
stored data could be classified. [ADR 0008](0008-remove-social-data.md) later removed them after
confirming that all social records were development-only.

## Consequences

The database and API gain a new entity and endpoint pair. Future comparison and inventory
features can use sessions without changing the meaning of a recipe. Legacy recipe result
columns remain accepted temporarily for client compatibility.
