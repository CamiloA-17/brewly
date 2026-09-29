-- Brew sessions are private observations that retain their snapshots.
BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c7', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'First plan', 15, 250, 'medium');

INSERT INTO brew_sessions (id, user_id, recipe_id, recipe_title, bean_name, method_slug,
                           dose_g, water_g, yield_g, tds_percent, elapsed_s, rating, acidity)
VALUES ('00000000-0000-0000-0000-0000000000d7', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000c7', 'First plan', 'Geisha Washed', 'v60',
        15, 250, 215, 1.38, 180, 4, 3);
SELECT pg_temp.expect_equal((SELECT extraction_yield_percent FROM brew_sessions
                             WHERE id = '00000000-0000-0000-0000-0000000000d7'),
                            19.78::numeric, 'session extraction yield');

SELECT pg_temp.expect_error($$
    INSERT INTO brew_sessions (user_id, recipe_id, recipe_title, bean_name, method_slug, dose_g, water_g, elapsed_s)
    VALUES ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000c7',
            'Stolen', 'Bean', 'v60', 15, 250, 180)$$, '23503');
SELECT pg_temp.expect_error($$
    INSERT INTO brew_sessions (user_id, recipe_title, bean_name, method_slug, dose_g, water_g, elapsed_s, acidity)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'Bad', 'Bean', 'v60', 15, 250, 180, 6)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO brew_sessions (user_id, recipe_title, bean_name, method_slug, dose_g, elapsed_s)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'No liquid', 'Bean', 'v60', 15, 180)$$, '23514');

UPDATE recipes SET title = 'Revised plan' WHERE id = '00000000-0000-0000-0000-0000000000c7';
SELECT pg_temp.expect_equal((SELECT recipe_title FROM brew_sessions WHERE id = '00000000-0000-0000-0000-0000000000d7'),
                            'First plan'::text, 'editing a plan leaves history unchanged');
DELETE FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c7';
SELECT pg_temp.expect_equal((SELECT recipe_id FROM brew_sessions WHERE id = '00000000-0000-0000-0000-0000000000d7'),
                            NULL::uuid, 'deleting a plan retains the session');

ROLLBACK;
