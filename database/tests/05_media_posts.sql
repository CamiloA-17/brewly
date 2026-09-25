-- Uploaded media, post photos and avatars.
BEGIN;
SELECT pg_temp.create_fixture_users();

-- Only JPEG images within the size and dimension limits are stored.
INSERT INTO media (id, owner_id, content_type, data, width, height) VALUES
    ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-00000000000a', 'image/jpeg', '\xffd8ffd9', 800, 600),
    ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-00000000000a', 'image/jpeg', '\xffd8ffd9', 800, 600),
    ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-00000000000a', 'image/jpeg', '\xffd8ffd9', 64, 64);
SELECT pg_temp.expect_error($$
    INSERT INTO media (owner_id, content_type, data, width, height)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'image/png', '\x89504e47', 10, 10)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO media (owner_id, content_type, data, width, height)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'image/jpeg', '\xffd8', 5000, 10)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO media (owner_id, content_type, data, width, height)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'image/jpeg', ''::bytea, 10, 10)$$, '23514');
SELECT pg_temp.expect_equal(
    (SELECT byte_size FROM media WHERE id = '00000000-0000-0000-0000-0000000000d1'), 4, 'byte size is generated');

-- A photo-only post is a text post without text; each image belongs to one post.
INSERT INTO posts (id, author_id, kind) VALUES
    ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000a', 'text'),
    ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-00000000000a', 'text');
INSERT INTO post_media (post_id, position, media_id) VALUES
    ('00000000-0000-0000-0000-0000000000e1', 1, '00000000-0000-0000-0000-0000000000d1'),
    ('00000000-0000-0000-0000-0000000000e1', 2, '00000000-0000-0000-0000-0000000000d2');
SELECT pg_temp.expect_error($$
    INSERT INTO post_media (post_id, position, media_id)
    VALUES ('00000000-0000-0000-0000-0000000000e2', 1, '00000000-0000-0000-0000-0000000000d1')$$, '23505');
SELECT pg_temp.expect_error($$
    INSERT INTO post_media (post_id, position, media_id)
    VALUES ('00000000-0000-0000-0000-0000000000e2', 5, '00000000-0000-0000-0000-0000000000d3')$$, '23514');

-- The avatar URL is derived from the avatar image.
UPDATE users SET avatar_media_id = '00000000-0000-0000-0000-0000000000d3'
WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal(
    (SELECT avatar_url FROM users WHERE id = '00000000-0000-0000-0000-00000000000a'),
    '/v1/media/00000000-0000-0000-0000-0000000000d3', 'avatar URL points to the media endpoint');
DELETE FROM media WHERE id = '00000000-0000-0000-0000-0000000000d3';
SELECT pg_temp.expect_equal(
    (SELECT avatar_url FROM users WHERE id = '00000000-0000-0000-0000-00000000000a'),
    NULL::text, 'deleting the image clears the avatar');

-- Deleting a post keeps no photo rows; deleting the account removes the images.
DELETE FROM posts WHERE id = '00000000-0000-0000-0000-0000000000e1';
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM post_media WHERE post_id = '00000000-0000-0000-0000-0000000000e1'),
    0::bigint, 'post photos are removed with the post');
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM media WHERE owner_id = '00000000-0000-0000-0000-00000000000a'),
    0::bigint, 'images are removed with the account');
ROLLBACK;
