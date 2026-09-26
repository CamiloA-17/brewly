-- Member equipment and grind settings.
BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO user_equipment (id, owner_id, kind, grinder_slug, is_default)
VALUES ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000a',
        'grinder', 'comandante_c40_mk4', true);
INSERT INTO equipment_grind_settings (equipment_id, method_slug, grind_setting)
VALUES ('00000000-0000-0000-0000-0000000000e1', 'v60', '24 clicks'),
       ('00000000-0000-0000-0000-0000000000e1', 'espresso', '8 clicks');
SELECT pg_temp.expect_equal((SELECT grind_setting FROM equipment_grind_settings
                             WHERE equipment_id = '00000000-0000-0000-0000-0000000000e1' AND method_slug = 'v60'),
                            '24 clicks', 'grind setting per method');

-- At most one default per kind; other kinds and other members are independent.
SELECT pg_temp.expect_error($$
    INSERT INTO user_equipment (owner_id, kind, brand, model, is_default)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'grinder', 'Baratza', 'Encore', true)$$, '23505');
INSERT INTO user_equipment (owner_id, kind, brand, model, is_default)
VALUES ('00000000-0000-0000-0000-00000000000a', 'grinder', 'Baratza', 'Encore', false),
       ('00000000-0000-0000-0000-00000000000a', 'kettle', 'Fellow', 'Stagg EKG', true),
       ('00000000-0000-0000-0000-00000000000b', 'grinder', 'Kingrinder', 'K6', true);

-- A catalog grinder only on grinders; every item needs a name.
SELECT pg_temp.expect_error($$
    INSERT INTO user_equipment (owner_id, kind, grinder_slug)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'kettle', 'comandante_c40_mk4')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO user_equipment (owner_id, kind, notes)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'scale', 'No name')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO user_equipment (owner_id, kind, brand)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'toaster', 'Acme')$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO user_equipment (owner_id, kind, grinder_slug)
    VALUES ('00000000-0000-0000-0000-00000000000a', 'grinder', 'unknown_grinder')$$, '23503');
SELECT pg_temp.expect_error($$
    INSERT INTO equipment_grind_settings (equipment_id, method_slug, grind_setting)
    VALUES ('00000000-0000-0000-0000-0000000000e1', 'chemex', '')$$, '23514');

-- Deleting the item, or the member, removes its settings.
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal((SELECT count(*) FROM user_equipment
                             WHERE owner_id = '00000000-0000-0000-0000-00000000000a'), 0::bigint, 'equipment deleted');
SELECT pg_temp.expect_equal((SELECT count(*) FROM equipment_grind_settings
                             WHERE equipment_id = '00000000-0000-0000-0000-0000000000e1'), 0::bigint, 'settings deleted');

ROLLBACK;
