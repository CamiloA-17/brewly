# ADR 0008: Remove social data and compatibility

## Status

Accepted, 2026-09-28.

## Context

The product has moved from a coffee social network to a private brewing companion. The rows in
the social graph, posts, comments, notifications, reports, recipe saves and remixes were all
development data. No user data needs to be exported or converted.

## Decision

Drop the social tables, `recipes.forked_from_id` and `can_view_content`. Delete media not used
as a current avatar. Remove recipe discovery and save routes, reject remix links, make all
existing recipes private and force every new or updated recipe to remain private.

The down migration reconstructs an empty version of the former schema for rollback testing. It
cannot restore the deleted test rows.

## Consequences

Recipes can only be read by their owners. The active app has no saved recipe or discovery flow,
and the seed contains only private brewing data. Old social source modules may be deleted in a
separate code cleanup because they are no longer wired into the application or API.
