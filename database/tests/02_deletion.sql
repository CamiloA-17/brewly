-- Deleting content and accounts.
BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO bean_varietals (bean_id, varietal_slug) VALUES ('00000000-0000-0000-0000-0000000000b1', 'geisha');
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'Morning V60', 15, 250, 'medium_fine');
INSERT INTO recipe_steps (recipe_id, position, kind) VALUES ('00000000-0000-0000-0000-0000000000c1', 1, 'bloom');
INSERT INTO posts (author_id, kind, recipe_id) VALUES
    ('00000000-0000-0000-0000-00000000000a', 'recipe', '00000000-0000-0000-0000-0000000000c1');
INSERT INTO follows (follower_id, followed_id) VALUES
    ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
INSERT INTO recipe_saves (user_id, recipe_id) VALUES
    ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000c1');
INSERT INTO user_brew_methods (user_id, method_slug) VALUES ('00000000-0000-0000-0000-00000000000a', 'v60');

-- A bean used by a recipe cannot be deleted (it can be archived instead).
SELECT pg_temp.expect_error($$
    DELETE FROM coffee_beans WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23503');
UPDATE coffee_beans SET archived_at = now() WHERE id = '00000000-0000-0000-0000-0000000000b1';

-- A catalog entry in use cannot be deleted.
SELECT pg_temp.expect_error($$DELETE FROM brew_methods WHERE slug = 'v60'$$, '23503');

-- Posts can only share the author's own content.
SELECT pg_temp.expect_error($$
    INSERT INTO posts (author_id, kind, recipe_id)
    VALUES ('00000000-0000-0000-0000-00000000000e', 'recipe', '00000000-0000-0000-0000-0000000000c1')$$, '23503');
SELECT pg_temp.expect_error($$
    INSERT INTO posts (author_id, kind) VALUES ('00000000-0000-0000-0000-00000000000e', 'text')$$, '23514');

-- Deleting a recipe removes its steps, saves and the posts that shared it.
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000b',
        '00000000-0000-0000-0000-0000000000b2', 'chemex', 'Leo Chemex', 30, 500, 'medium_coarse');
INSERT INTO posts (author_id, kind, recipe_id) VALUES
    ('00000000-0000-0000-0000-00000000000b', 'recipe', '00000000-0000-0000-0000-0000000000c2');
DELETE FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c2';
SELECT pg_temp.expect_equal((SELECT count(*) FROM posts WHERE author_id = '00000000-0000-0000-0000-00000000000b'),
                            0::bigint, 'posts of a deleted recipe are removed');

-- Deleting an account removes everything the user owns, in one statement.
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal((SELECT count(*) FROM coffee_beans WHERE owner_id = '00000000-0000-0000-0000-00000000000a'),
                            0::bigint, 'beans deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM recipes WHERE author_id = '00000000-0000-0000-0000-00000000000a'),
                            0::bigint, 'recipes deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM recipe_steps), 0::bigint, 'steps deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM recipe_saves), 0::bigint, 'saves deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM follows), 0::bigint, 'follows deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM bean_varietals), 0::bigint, 'bean varietals deleted with account');
SELECT pg_temp.expect_equal((SELECT count(*) FROM users), 2::bigint, 'other users untouched');

ROLLBACK;
