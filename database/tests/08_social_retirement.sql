-- The retired social schema is absent, while brewing data remains available.
BEGIN;

SELECT pg_temp.expect_equal(to_regclass('public.follows'), NULL::regclass, 'follows removed');
SELECT pg_temp.expect_equal(to_regclass('public.posts'), NULL::regclass, 'posts removed');
SELECT pg_temp.expect_equal(to_regclass('public.post_media'), NULL::regclass, 'post media removed');
SELECT pg_temp.expect_equal(to_regclass('public.comments'), NULL::regclass, 'comments removed');
SELECT pg_temp.expect_equal(to_regclass('public.recipe_saves'), NULL::regclass, 'recipe saves removed');
SELECT pg_temp.expect_equal(to_regclass('public.notifications'), NULL::regclass, 'notifications removed');
SELECT pg_temp.expect_equal(to_regclass('public.reports'), NULL::regclass, 'reports removed');
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'forked_from_id'),
    0::bigint, 'remix link removed');
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM recipes WHERE visibility <> 'private'),
    0::bigint, 'recipes are private');
SELECT pg_temp.expect_equal(
    (SELECT count(*) FROM coffee_beans WHERE visibility <> 'private'),
    0::bigint, 'beans are private');

SELECT pg_temp.create_fixture_users();
SELECT pg_temp.expect_error($$
    UPDATE coffee_beans SET visibility = 'public'
    WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23514');
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c8', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'Private plan', 15, 250, 'medium');
SELECT pg_temp.expect_error($$
    UPDATE recipes SET visibility = 'public'
    WHERE id = '00000000-0000-0000-0000-0000000000c8'$$, '23514');

ROLLBACK;
