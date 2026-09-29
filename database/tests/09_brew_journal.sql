-- Brew journal: ownership, generated values, ranges and deletion rules.
BEGIN;
SELECT pg_temp.create_fixture_users();

UPDATE coffee_beans SET weight_g = 250, remaining_g = 250 WHERE id = '00000000-0000-0000-0000-0000000000b1';
INSERT INTO user_equipment (id, owner_id, kind, grinder_slug)
VALUES ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000a', 'grinder', 'comandante_c40_mk4'),
       ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-00000000000b', 'grinder', 'niche_zero');

INSERT INTO brew_logs (id, user_id, bean_id, method_slug, equipment_id, dose_g, water_g, yield_g, tds_percent,
                       rating, acidity, sweetness)
VALUES ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', '00000000-0000-0000-0000-0000000000e1',
        15, 250, 215, 1.38, 4, 4, 5);
SELECT pg_temp.expect_equal((SELECT ratio FROM brew_logs WHERE id = '00000000-0000-0000-0000-0000000000f1'),
                            16.67::numeric, 'brew ratio');
SELECT pg_temp.expect_equal((SELECT extraction_yield_percent FROM brew_logs
                             WHERE id = '00000000-0000-0000-0000-0000000000f1'), 19.78::numeric, 'brew EY');
SELECT pg_temp.expect_equal((SELECT visibility::text FROM brew_logs
                             WHERE id = '00000000-0000-0000-0000-0000000000f1'), 'private', 'private by default');

-- Only the member's own bean and equipment.
SELECT pg_temp.expect_error($$
    INSERT INTO brew_logs (user_id, bean_id, method_slug, dose_g, water_g)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b2', 'v60', 15, 250)$$,
    '23503');
SELECT pg_temp.expect_error($$
    INSERT INTO brew_logs (user_id, bean_id, method_slug, equipment_id, dose_g, water_g)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1', 'v60',
            '00000000-0000-0000-0000-0000000000e2', 15, 250)$$, '23503');

-- Ranges.
SELECT pg_temp.expect_error($$
    INSERT INTO brew_logs (user_id, bean_id, method_slug, dose_g)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1', 'v60', 15)$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO brew_logs (user_id, bean_id, method_slug, dose_g, water_g, bitterness)
    VALUES ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1', 'v60', 15, 250, 6)$$,
    '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO coffee_beans (owner_id, name, remaining_g)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'Negative', -1)$$, '23514');

-- Deleting the equipment keeps the brew; a bean with brews can't be deleted.
DELETE FROM user_equipment WHERE id = '00000000-0000-0000-0000-0000000000e1';
SELECT pg_temp.expect_equal((SELECT equipment_id FROM brew_logs WHERE id = '00000000-0000-0000-0000-0000000000f1'),
                            NULL::uuid, 'equipment forgotten');
SELECT pg_temp.expect_error($$
    DELETE FROM coffee_beans WHERE id = '00000000-0000-0000-0000-0000000000b1'$$, '23503');

-- Deleting the recipe keeps the brew.
INSERT INTO recipes (id, author_id, bean_id, method_slug, title, dose_g, water_g, grind_size)
VALUES ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-0000000000b1', 'v60', 'Morning V60', 15, 250, 'medium_fine');
UPDATE brew_logs SET recipe_id = '00000000-0000-0000-0000-0000000000c1'
WHERE id = '00000000-0000-0000-0000-0000000000f1';
DELETE FROM recipes WHERE id = '00000000-0000-0000-0000-0000000000c1';
SELECT pg_temp.expect_equal((SELECT recipe_id FROM brew_logs WHERE id = '00000000-0000-0000-0000-0000000000f1'),
                            NULL::uuid, 'recipe forgotten');

-- Deleting the member removes the journal.
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal((SELECT count(*) FROM brew_logs
                             WHERE id = '00000000-0000-0000-0000-0000000000f1'), 0::bigint, 'journal deleted');

ROLLBACK;
