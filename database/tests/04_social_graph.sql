-- Follows, saves and remixes.
BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'Morning V60', 15, 250, 'medium_fine');

-- Nobody can follow themselves, and a follow is stored once.
SELECT pg_temp.expect_error($$
    INSERT INTO follows (follower_id, followed_id)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a')$$, '23514');
INSERT INTO follows (follower_id, followed_id)
VALUES ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
SELECT pg_temp.expect_error($$
    INSERT INTO follows (follower_id, followed_id)
    VALUES ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a')$$, '23505');

-- A remix uses the remixer's own bean.
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, forked_from_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1',
            '00000000-0000-0000-0000-0000000000c1', 'v60', 'Remix', 15, 250, 'medium_fine')$$, '23503');
INSERT INTO recipes (id, author_id, bean_id, forked_from_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000b',
        '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000c1',
        'v60', 'Remix', 15, 250, 'medium_fine');
INSERT INTO recipe_saves (user_id, recipe_id)
VALUES ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000c1');

-- Deleting the original keeps the remix without the link, and removes its saves.
DELETE FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c1';
SELECT pg_temp.expect_equal(
    (SELECT forked_from_id FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c2'),
    NULL::uuid, 'remix keeps existing without its original');
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM recipe_saves WHERE recipe_id = '00000000-0000-0000-0000-0000000000c1'),
    0::bigint, 'saves of a deleted recipe are removed');

-- A block hides members from each other, which the API checks with can_view_content(..., 'public').
INSERT INTO user_blocks (blocker_id, blocked_id)
VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
SELECT pg_temp.expect_equal(
    can_view_content('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a', 'public'),
    false, 'blocked member cannot see the blocker');
SELECT pg_temp.expect_equal(
    can_view_content('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a', 'public'),
    true, 'other members are visible');
ROLLBACK;
