-- migrate:up

-- Brewly is a private brewing companion. The social content in these tables was
-- development data, so it can be removed instead of migrated or exported.
DELETE FROM media m
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.avatar_media_id = m.id);

DROP TABLE reports;
DROP TABLE notifications;
DROP TABLE comments;
DROP TABLE post_likes;
DROP TABLE post_media;
DROP TABLE posts;
DROP FUNCTION can_view_content(uuid, uuid, visibility);
DROP TABLE user_blocks;
DROP TABLE follows;
DROP TABLE recipe_saves;

ALTER TABLE recipes DROP COLUMN forked_from_id;

-- Every remaining recipe is a private plan owned by its author.
UPDATE recipes SET visibility = 'private' WHERE visibility <> 'private';
ALTER TABLE recipes ALTER COLUMN visibility SET DEFAULT 'private';
ALTER TABLE recipes ADD CONSTRAINT recipes_private_only CHECK (visibility = 'private');
UPDATE coffee_beans SET visibility = 'private' WHERE visibility <> 'private';
ALTER TABLE coffee_beans ALTER COLUMN visibility SET DEFAULT 'private';
ALTER TABLE coffee_beans ADD CONSTRAINT coffee_beans_private_only CHECK (visibility = 'private');

-- migrate:down

ALTER TABLE recipes DROP CONSTRAINT IF EXISTS recipes_private_only;
ALTER TABLE coffee_beans DROP CONSTRAINT IF EXISTS coffee_beans_private_only;
ALTER TABLE recipes ALTER COLUMN visibility SET DEFAULT 'public';
ALTER TABLE coffee_beans ALTER COLUMN visibility SET DEFAULT 'public';
ALTER TABLE recipes
    ADD COLUMN forked_from_id uuid REFERENCES recipes (id) ON DELETE SET NULL;
CREATE INDEX recipes_forked_from_idx ON recipes (forked_from_id);

CREATE TABLE recipe_saves (
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id  uuid        NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);
CREATE INDEX recipe_saves_recipe_idx ON recipe_saves (recipe_id);

CREATE TABLE follows (
    follower_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    followed_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT follows_not_self CHECK (follower_id <> followed_id)
);
CREATE INDEX follows_followed_idx ON follows (followed_id);

CREATE TABLE user_blocks (
    blocker_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT user_blocks_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX user_blocks_blocked_idx ON user_blocks (blocked_id);

CREATE TABLE posts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind text NOT NULL,
    body text,
    recipe_id uuid,
    bean_id uuid,
    visibility visibility NOT NULL DEFAULT 'public',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT posts_recipe_owned_by_author FOREIGN KEY (recipe_id, author_id)
        REFERENCES recipes (id, author_id) ON DELETE CASCADE,
    CONSTRAINT posts_bean_owned_by_author FOREIGN KEY (bean_id, author_id)
        REFERENCES coffee_beans (id, owner_id) ON DELETE CASCADE,
    CONSTRAINT posts_kind_check CHECK (kind IN ('text', 'recipe', 'bean')),
    CONSTRAINT posts_body_length CHECK (body IS NULL OR char_length(body) BETWEEN 1 AND 2000),
    CONSTRAINT posts_kind_attachment CHECK (
        CASE kind
            WHEN 'text' THEN recipe_id IS NULL AND bean_id IS NULL
            WHEN 'recipe' THEN recipe_id IS NOT NULL AND bean_id IS NULL
            WHEN 'bean' THEN bean_id IS NOT NULL AND recipe_id IS NULL
        END)
);
CREATE INDEX posts_author_created_idx ON posts (author_id, created_at DESC, id DESC);
CREATE INDEX posts_created_idx ON posts (created_at DESC, id DESC);
CREATE INDEX posts_recipe_idx ON posts (recipe_id);
CREATE INDEX posts_bean_idx ON posts (bean_id);
CREATE INDEX posts_public_created_idx ON posts (created_at DESC, id DESC) WHERE visibility = 'public';
CREATE TRIGGER posts_set_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE post_media (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id uuid NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    position smallint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    media_id uuid NOT NULL REFERENCES media (id) ON DELETE CASCADE,
    CONSTRAINT post_media_post_position_key UNIQUE (post_id, position),
    CONSTRAINT post_media_media_key UNIQUE (media_id),
    CONSTRAINT post_media_position_check CHECK (position BETWEEN 1 AND 4)
);

CREATE TABLE post_likes (
    post_id uuid NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);
CREATE INDEX post_likes_user_idx ON post_likes (user_id, created_at DESC);

CREATE TABLE comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id uuid NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    author_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    parent_id uuid,
    body text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT comments_id_post_key UNIQUE (id, post_id),
    CONSTRAINT comments_parent_same_post FOREIGN KEY (parent_id, post_id)
        REFERENCES comments (id, post_id) ON DELETE CASCADE,
    CONSTRAINT comments_body_length CHECK (char_length(body) BETWEEN 1 AND 1000)
);
CREATE INDEX comments_post_created_idx ON comments (post_id, created_at);
CREATE INDEX comments_parent_idx ON comments (parent_id);
CREATE INDEX comments_author_idx ON comments (author_id);
CREATE TRIGGER comments_set_updated_at BEFORE UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE FUNCTION can_view_content(p_viewer uuid, p_owner uuid, p_visibility visibility)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT coalesce(p_viewer = p_owner, false)
        OR (NOT EXISTS (
                SELECT 1 FROM user_blocks b
                WHERE (b.blocker_id = p_owner AND b.blocked_id = p_viewer)
                   OR (b.blocker_id = p_viewer AND b.blocked_id = p_owner))
            AND (p_visibility = 'public' OR (p_visibility = 'followers' AND EXISTS (
                SELECT 1 FROM follows f
                WHERE f.follower_id = p_viewer AND f.followed_id = p_owner))))
$$;

CREATE TABLE notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    actor_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind text NOT NULL,
    post_id uuid REFERENCES posts (id) ON DELETE CASCADE,
    comment_id uuid REFERENCES comments (id) ON DELETE CASCADE,
    recipe_id uuid REFERENCES recipes (id) ON DELETE CASCADE,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notifications_not_self CHECK (recipient_id <> actor_id),
    CONSTRAINT notifications_kind_check CHECK (kind IN
        ('follow', 'post_like', 'comment', 'comment_reply', 'recipe_save', 'recipe_fork')),
    CONSTRAINT notifications_kind_target CHECK (
        CASE kind
            WHEN 'follow' THEN num_nonnulls(post_id, comment_id, recipe_id) = 0
            WHEN 'post_like' THEN post_id IS NOT NULL AND comment_id IS NULL AND recipe_id IS NULL
            WHEN 'comment' THEN post_id IS NOT NULL AND comment_id IS NOT NULL AND recipe_id IS NULL
            WHEN 'comment_reply' THEN post_id IS NOT NULL AND comment_id IS NOT NULL AND recipe_id IS NULL
            WHEN 'recipe_save' THEN recipe_id IS NOT NULL AND post_id IS NULL AND comment_id IS NULL
            WHEN 'recipe_fork' THEN recipe_id IS NOT NULL AND post_id IS NULL AND comment_id IS NULL
        END)
);
CREATE INDEX notifications_recipient_created_idx ON notifications (recipient_id, created_at DESC, id DESC);
CREATE INDEX notifications_unread_idx ON notifications (recipient_id) WHERE read_at IS NULL;
CREATE INDEX notifications_actor_idx ON notifications (actor_id);
CREATE INDEX notifications_post_idx ON notifications (post_id);
CREATE INDEX notifications_comment_idx ON notifications (comment_id);
CREATE INDEX notifications_recipe_idx ON notifications (recipe_id);
CREATE UNIQUE INDEX notifications_once_idx ON notifications (
    recipient_id, actor_id, kind,
    coalesce(post_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(recipe_id, '00000000-0000-0000-0000-000000000000'::uuid)
) WHERE kind IN ('follow', 'post_like', 'recipe_save');

CREATE TABLE reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    reported_user_id uuid REFERENCES users (id) ON DELETE CASCADE,
    post_id uuid REFERENCES posts (id) ON DELETE CASCADE,
    comment_id uuid REFERENCES comments (id) ON DELETE CASCADE,
    recipe_id uuid REFERENCES recipes (id) ON DELETE CASCADE,
    reason text NOT NULL,
    details text,
    status text NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT reports_single_target CHECK (num_nonnulls(reported_user_id, post_id, comment_id, recipe_id) = 1),
    CONSTRAINT reports_reason_check CHECK (reason IN
        ('spam', 'harassment', 'hate', 'sexual_content', 'violence', 'misinformation', 'other')),
    CONSTRAINT reports_status_check CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
    CONSTRAINT reports_details_length CHECK (details IS NULL OR char_length(details) <= 1000)
);
CREATE INDEX reports_status_created_idx ON reports (status, created_at);
CREATE INDEX reports_reporter_idx ON reports (reporter_id);
CREATE INDEX reports_reported_user_idx ON reports (reported_user_id);
CREATE INDEX reports_post_idx ON reports (post_id);
CREATE INDEX reports_comment_idx ON reports (comment_id);
CREATE INDEX reports_recipe_idx ON reports (recipe_id);
