-- migrate:up

CREATE TABLE follows (
    follower_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    followed_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followed_id),
    CONSTRAINT follows_not_self CHECK (follower_id <> followed_id)
);
CREATE INDEX follows_followed_idx ON follows (followed_id);

CREATE TABLE user_blocks (
    blocker_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT user_blocks_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX user_blocks_blocked_idx ON user_blocks (blocked_id);

-- Feed items. A post is plain text, or shares one of the author's own recipes or beans.
CREATE TABLE posts (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id   uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind        text        NOT NULL,
    body        text,
    recipe_id   uuid,
    bean_id     uuid,
    visibility  visibility  NOT NULL DEFAULT 'public',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT posts_recipe_owned_by_author FOREIGN KEY (recipe_id, author_id)
        REFERENCES recipes (id, author_id) ON DELETE CASCADE,
    CONSTRAINT posts_bean_owned_by_author FOREIGN KEY (bean_id, author_id)
        REFERENCES coffee_beans (id, owner_id) ON DELETE CASCADE,
    CONSTRAINT posts_kind_check CHECK (kind IN ('text', 'recipe', 'bean')),
    CONSTRAINT posts_body_length CHECK (body IS NULL OR char_length(body) BETWEEN 1 AND 2000),
    CONSTRAINT posts_kind_attachment CHECK (
        CASE kind
            WHEN 'text'   THEN body IS NOT NULL AND recipe_id IS NULL AND bean_id IS NULL
            WHEN 'recipe' THEN recipe_id IS NOT NULL AND bean_id IS NULL
            WHEN 'bean'   THEN bean_id IS NOT NULL AND recipe_id IS NULL
        END)
);
CREATE INDEX posts_author_created_idx ON posts (author_id, created_at DESC, id DESC);
CREATE INDEX posts_created_idx ON posts (created_at DESC, id DESC);
CREATE INDEX posts_recipe_idx ON posts (recipe_id);
CREATE INDEX posts_bean_idx ON posts (bean_id);

CREATE TRIGGER posts_set_updated_at
    BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE post_media (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     uuid        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    position    smallint    NOT NULL,
    media_type  text        NOT NULL,
    url         text        NOT NULL,
    width       integer,
    height      integer,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT post_media_post_position_key UNIQUE (post_id, position),
    CONSTRAINT post_media_position_check CHECK (position BETWEEN 1 AND 10),
    CONSTRAINT post_media_type_check CHECK (media_type IN ('image', 'video')),
    CONSTRAINT post_media_dimensions_check CHECK ((width IS NULL OR width > 0) AND (height IS NULL OR height > 0))
);

CREATE TABLE post_likes (
    post_id     uuid        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);
CREATE INDEX post_likes_user_idx ON post_likes (user_id, created_at DESC);

CREATE TABLE comments (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id     uuid        NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    author_id   uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    parent_id   uuid,
    body        text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT comments_id_post_key UNIQUE (id, post_id),
    -- A reply must belong to the same post as its parent.
    CONSTRAINT comments_parent_same_post FOREIGN KEY (parent_id, post_id)
        REFERENCES comments (id, post_id) ON DELETE CASCADE,
    CONSTRAINT comments_body_length CHECK (char_length(body) BETWEEN 1 AND 1000)
);
CREATE INDEX comments_post_created_idx ON comments (post_id, created_at);
CREATE INDEX comments_parent_idx ON comments (parent_id);
CREATE INDEX comments_author_idx ON comments (author_id);

CREATE TRIGGER comments_set_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Single source of truth for "can this viewer see this owner's content?".
-- Owners always see their own content; blocks in either direction hide everything else.
CREATE FUNCTION can_view_content(p_viewer uuid, p_owner uuid, p_visibility visibility)
RETURNS boolean
LANGUAGE sql STABLE AS $$
    SELECT coalesce(p_viewer = p_owner, false)
        OR (
            NOT EXISTS (
                SELECT 1 FROM user_blocks b
                WHERE (b.blocker_id = p_owner AND b.blocked_id = p_viewer)
                   OR (b.blocker_id = p_viewer AND b.blocked_id = p_owner)
            )
            AND (
                p_visibility = 'public'
                OR (p_visibility = 'followers' AND EXISTS (
                    SELECT 1 FROM follows f
                    WHERE f.follower_id = p_viewer AND f.followed_id = p_owner
                ))
            )
        )
$$;

-- migrate:down

DROP FUNCTION can_view_content(uuid, uuid, visibility);
DROP TABLE comments;
DROP TABLE post_likes;
DROP TABLE post_media;
DROP TABLE posts;
DROP TABLE user_blocks;
DROP TABLE follows;
