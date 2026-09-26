-- Recipe parameters, generated columns and ownership rules.
BEGIN;
SELECT pg_temp.create_fixture_users();

-- V60: ratio from brew water. Results (TDS, EY, rating) live in brew_logs.
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, yield_g, grind_size,
                     servings, ice_g, brewer_detail)
VALUES ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'Morning V60', 15, 250, 215, 'medium_fine',
        1, 80, 'V60 02 ceramic');
SELECT pg_temp.expect_equal((SELECT ratio FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c1'),
                            16.67::numeric, 'filter ratio uses water');

-- Espresso: ratio from beverage weight.
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, yield_g, grind_size, pressure_bar)
VALUES ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'espresso', 'Classic shot', 18, 36, 'fine', 9);
SELECT pg_temp.expect_equal((SELECT ratio FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c2'),
                            2.00::numeric, 'espresso ratio uses beverage');

-- Milk drinks built on espresso.
UPDATE recipes SET drink_type = 'flat_white', milk_g = 120 WHERE id = '00000000-0000-0000-0000-0000000000c2';
SELECT pg_temp.expect_error($$
    UPDATE recipes SET drink_type = 'frappe' WHERE id = '00000000-0000-0000-0000-0000000000c2'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE recipes SET servings = 0 WHERE id = '00000000-0000-0000-0000-0000000000c2'$$, '23514');

-- updated_at trigger.
UPDATE recipes SET updated_at = now() - interval '1 day' WHERE id = '00000000-0000-0000-0000-0000000000c2';
UPDATE recipes SET title = 'Classic shot v2' WHERE id = '00000000-0000-0000-0000-0000000000c2';
SELECT pg_temp.expect_equal((SELECT updated_at > now() - interval '1 minute' FROM recipes
                             WHERE id = '00000000-0000-0000-0000-0000000000c2'), true, 'updated_at refreshed');

-- A recipe cannot use somebody else's bean (composite foreign key).
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b2',
            'v60', 'Stolen bean', 15, 250, 'medium')$$, '23503');

-- Required parameters and ranges.
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'No water', 15, 'medium')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'Zero dose', 0, 250, 'medium')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'Absurd ratio', 1, 900, 'medium')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'Bad grind', 15, 250, 'powder')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size, bloom_water_g)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'Bloom overflow', 15, 250, 'medium', 300)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size, water_temp_c)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'v60', 'Too hot', 15, 250, 'medium', 120)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO recipes (author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
            'unknown_method', 'Unknown method', 15, 250, 'medium')$$, '23503');
SELECT pg_temp.expect_error($$
    UPDATE recipes SET ratio = 10 WHERE id = '00000000-0000-0000-0000-0000000000c1'$$, '428C9');

-- Steps: ordered, typed, unique per position.
INSERT INTO recipe_steps (recipe_id, position, kind, start_s, water_target_g, instruction) VALUES
    ('00000000-0000-0000-0000-0000000000c1', 1, 'bloom', 0, 45, 'Bloom and swirl'),
    ('00000000-0000-0000-0000-0000000000c1', 2, 'pour', 45, 150, 'Slow spiral pour'),
    ('00000000-0000-0000-0000-0000000000c1', 3, 'pour', 90, 250, NULL);
SELECT pg_temp.expect_error($$
    INSERT INTO recipe_steps (recipe_id, position, kind) VALUES ('00000000-0000-0000-0000-0000000000c1', 3, 'pour')$$,
    '23505');
SELECT pg_temp.expect_error($$
    INSERT INTO recipe_steps (recipe_id, position, kind) VALUES ('00000000-0000-0000-0000-0000000000c1', 4, 'dance')$$,
    '23514');

-- Beans: altitude range and domains.
SELECT pg_temp.expect_error($$
    INSERT INTO coffee_beans (owner_id, name, altitude_min_m, altitude_max_m)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'Upside down', 2000, 1500)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO coffee_beans (owner_id, name, roast_level)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'Burnt', 'charcoal')$$, '23514');

-- Users.
SELECT pg_temp.expect_error($$
    INSERT INTO users (username, display_name) VALUES ('Bad Name', 'Bad')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO users (username, display_name) VALUES ('ana.test', 'Duplicate')$$, '23505');
SELECT pg_temp.expect_error($$
    INSERT INTO auth_identities (user_id, provider, subject)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'password', 'ana@test.example.com')$$, '23514');

ROLLBACK;
