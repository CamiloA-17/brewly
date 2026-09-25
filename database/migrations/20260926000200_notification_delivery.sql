-- migrate:up

-- Follows, likes and saves can be undone and redone; they notify once per actor and target.
-- Inserts use ON CONFLICT DO NOTHING, which respects this index.
CREATE UNIQUE INDEX notifications_once_idx ON notifications (
    recipient_id, actor_id, kind,
    coalesce(post_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(recipe_id, '00000000-0000-0000-0000-000000000000'::uuid)
) WHERE kind IN ('follow', 'post_like', 'recipe_save');

-- Keyset pagination of a user's notifications over (created_at, id).
DROP INDEX notifications_recipient_created_idx;
CREATE INDEX notifications_recipient_created_idx ON notifications (recipient_id, created_at DESC, id DESC);

COMMENT ON COLUMN notifications.recipe_id IS
    'The saved recipe (recipe_save) or the new remix (recipe_fork).';

-- migrate:down

COMMENT ON COLUMN notifications.recipe_id IS NULL;
DROP INDEX notifications_recipient_created_idx;
CREATE INDEX notifications_recipient_created_idx ON notifications (recipient_id, created_at DESC);
DROP INDEX notifications_once_idx;
