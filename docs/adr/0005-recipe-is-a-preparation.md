# ADR 0005: A recipe is a preparation

- Status: accepted
- Date: 2026-09-25

## Context

Barista apps often separate a reusable recipe from a log of each brew session. For Brewly, the
product decision is that "recipes" and "preparations" are the same thing.

## Decision

A single `recipes` table holds the full preparation: bean, method, dose, water or beverage
weight, generated ratio, grind (size, grinder, setting, microns), temperature, bloom, total time,
pressure, filter, water, ordered steps and results (TDS, generated extraction yield, rating,
tasting notes). Each recipe uses one of its author's beans. Recipes can be forked later
(`forked_from_id`) so others can brew them with their own beans.

## Consequences

- Simple model and UI: one form, one list.
- Dialing in the same coffee produces several recipes; a separate brew log can be added later
  without breaking this model.
