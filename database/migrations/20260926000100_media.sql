-- migrate:up

-- Photos are stored in PostgreSQL (see docs/adr/0006-media-in-postgresql.md). The app always
-- reads them through /v1/media/{id}, so they can move to object storage without an app change.
CREATE TABLE media (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    content_type  text        NOT NULL,
    data          bytea       NOT NULL,
    byte_size     integer     GENERATED ALWAYS AS (octet_length(data)) STORED,
    width         integer     NOT NULL,
    height        integer     NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT media_content_type_check CHECK (content_type = 'image/jpeg'),
    CONSTRAINT media_size_check CHECK (octet_length(data) BETWEEN 1 AND 2097152),
    CONSTRAINT media_dimensions_check CHECK (width BETWEEN 1 AND 4096 AND height BETWEEN 1 AND 4096)
);
-- JPEG data is already compressed; skip TOAST compression.
ALTER TABLE media ALTER COLUMN data SET STORAGE EXTERNAL;
CREATE INDEX media_owner_created_idx ON media (owner_id, created_at);

COMMENT ON TABLE media IS 'Uploaded images (JPEG, at most 2 MB), served by the API at /v1/media/{id}.';

-- Post photos reference uploaded media instead of external URLs.
ALTER TABLE post_media
    DROP CONSTRAINT post_media_type_check,
    DROP CONSTRAINT post_media_dimensions_check,
    DROP COLUMN media_type,
    DROP COLUMN url,
    DROP COLUMN width,
    DROP COLUMN height,
    ADD COLUMN media_id uuid NOT NULL REFERENCES media (id) ON DELETE CASCADE,
    ADD CONSTRAINT post_media_media_key UNIQUE (media_id),
    DROP CONSTRAINT post_media_position_check,
    ADD CONSTRAINT post_media_position_check CHECK (position BETWEEN 1 AND 4);

COMMENT ON TABLE post_media IS 'Photos of a post, in order. Each uploaded image belongs to one post.';

-- A text post may be only photos; the API requires text or photos.
ALTER TABLE posts
    DROP CONSTRAINT posts_kind_attachment,
    ADD CONSTRAINT posts_kind_attachment CHECK (
        CASE kind
            WHEN 'text'   THEN recipe_id IS NULL AND bean_id IS NULL
            WHEN 'recipe' THEN recipe_id IS NOT NULL AND bean_id IS NULL
            WHEN 'bean'   THEN bean_id IS NOT NULL AND recipe_id IS NULL
        END);

-- Avatars are uploaded media too; avatar_url is derived so it can't point anywhere else.
ALTER TABLE users
    DROP COLUMN avatar_url,
    ADD COLUMN avatar_media_id uuid REFERENCES media (id) ON DELETE SET NULL,
    ADD COLUMN avatar_url text GENERATED ALWAYS AS ('/v1/media/' || avatar_media_id::text) STORED;
CREATE INDEX users_avatar_media_idx ON users (avatar_media_id);

-- Feeds list the posts of followed members newest first.
CREATE INDEX posts_public_created_idx ON posts (created_at DESC, id DESC) WHERE visibility = 'public';

-- migrate:down

DROP INDEX posts_public_created_idx;

ALTER TABLE users
    DROP COLUMN avatar_url,
    DROP COLUMN avatar_media_id,
    ADD COLUMN avatar_url text;

ALTER TABLE posts
    DROP CONSTRAINT posts_kind_attachment,
    ADD CONSTRAINT posts_kind_attachment CHECK (
        CASE kind
            WHEN 'text'   THEN body IS NOT NULL AND recipe_id IS NULL AND bean_id IS NULL
            WHEN 'recipe' THEN recipe_id IS NOT NULL AND bean_id IS NULL
            WHEN 'bean'   THEN bean_id IS NOT NULL AND recipe_id IS NULL
        END);

DELETE FROM post_media;
ALTER TABLE post_media
    DROP CONSTRAINT post_media_position_check,
    ADD CONSTRAINT post_media_position_check CHECK (position BETWEEN 1 AND 10),
    DROP COLUMN media_id,
    ADD COLUMN media_type text NOT NULL,
    ADD COLUMN url text NOT NULL,
    ADD COLUMN width integer,
    ADD COLUMN height integer,
    ADD CONSTRAINT post_media_type_check CHECK (media_type IN ('image', 'video')),
    ADD CONSTRAINT post_media_dimensions_check CHECK ((width IS NULL OR width > 0) AND (height IS NULL OR height > 0));

DROP TABLE media;
