-- The global catalog must be usable in a fresh production database without the dev seed.
BEGIN;

SELECT pg_temp.expect_equal((SELECT count(*) >= 46 FROM countries), true, 'coffee origins are seeded');
SELECT pg_temp.expect_equal((SELECT count(*) >= 37 FROM varietals), true, 'varietals are seeded');
SELECT pg_temp.expect_equal((SELECT count(*) >= 20 FROM processing_methods), true, 'processes are seeded');
SELECT pg_temp.expect_equal((SELECT count(*) >= 18 FROM brew_methods), true, 'brew methods are seeded');
SELECT pg_temp.expect_equal((SELECT count(*) >= 20 FROM grinders), true, 'grinders are seeded');
SELECT pg_temp.expect_equal((SELECT count(*) >= 51 FROM flavor_notes), true, 'flavor notes are seeded');

SELECT pg_temp.expect_equal((SELECT count(*) FROM countries WHERE btrim(name) = ''), 0::bigint,
                            'country names are present');
SELECT pg_temp.expect_equal((SELECT count(*) FROM varietals WHERE btrim(name) = ''), 0::bigint,
                            'varietal names are present');
SELECT pg_temp.expect_equal((SELECT count(*) FROM processing_methods WHERE btrim(name) = ''), 0::bigint,
                            'process names are present');
SELECT pg_temp.expect_equal((SELECT count(*) FROM brew_methods WHERE btrim(name) = ''), 0::bigint,
                            'brew method names are present');
SELECT pg_temp.expect_equal((SELECT count(*) FROM grinders WHERE btrim(brand) = '' OR btrim(model) = ''),
                            0::bigint, 'grinder names are present');
SELECT pg_temp.expect_equal((SELECT count(*) FROM flavor_notes WHERE btrim(name) = ''), 0::bigint,
                            'flavor note names are present');

SELECT pg_temp.expect_equal((SELECT count(*) FROM brew_methods
                             WHERE default_ratio IS NOT NULL AND default_ratio NOT BETWEEN 0.5 AND 50),
                            0::bigint, 'method defaults fit recipe ratio rules');
SELECT pg_temp.expect_equal((SELECT ratio_basis FROM brew_methods WHERE slug = 'espresso'),
                            'beverage'::text, 'espresso ratio uses beverage weight');
SELECT pg_temp.expect_equal((SELECT ratio_basis FROM brew_methods WHERE slug = 'v60'),
                            'water'::text, 'filter ratio uses water weight');

ROLLBACK;
