-- Demo data for local development only. Never run against production.
-- Both demo accounts use the password in the DEMO_PASSWORD variable of your .env file,
-- which is never committed:
--
--   make db-seed      (or: psql "$DATABASE_URL" -v demo_password=... -f database/seeds/dev_seed.sql)

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (id, username, display_name, email, bio, first_name, last_name, birth_date,
                   country_code, city, terms_accepted_at, onboarding_completed_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 'ana.barista', 'Ana', 'ana@example.com',
     'Home barista. Pour-over nerd.', 'Ana', 'Demo', '1995-04-12', 'CO', 'Bogotá', now(), now()),
    ('22222222-2222-4222-8222-222222222222', 'leo.roaster', 'Leo', 'leo@example.com',
     'Small-batch roaster. Espresso every morning.', 'Leo', 'Demo', '1990-11-03', 'CO', 'Medellín', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth_identities (user_id, provider, subject, password_hash) VALUES
    ('11111111-1111-4111-8111-111111111111', 'password', 'ana@example.com', crypt(:'demo_password', gen_salt('bf', 10))),
    ('22222222-2222-4222-8222-222222222222', 'password', 'leo@example.com', crypt(:'demo_password', gen_salt('bf', 10)))
ON CONFLICT (provider, subject) DO NOTHING;

INSERT INTO follows (follower_id, followed_id) VALUES
    ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222'),
    ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111')
ON CONFLICT DO NOTHING;

INSERT INTO user_brew_methods (user_id, method_slug) VALUES
    ('11111111-1111-4111-8111-111111111111', 'v60'),
    ('11111111-1111-4111-8111-111111111111', 'aeropress'),
    ('22222222-2222-4222-8222-222222222222', 'espresso'),
    ('22222222-2222-4222-8222-222222222222', 'chemex')
ON CONFLICT DO NOTHING;

INSERT INTO coffee_beans
    (id, owner_id, name, roaster, country_code, region, farm, producer, altitude_min_m, altitude_max_m,
     processing_method_slug, roast_level, roast_date, harvest_year, sca_score, weight_g, notes)
VALUES
    ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
     'Geisha Washed (demo)', 'Demo Roasters', 'CO', 'Huila', 'Finca Las Nubes (demo)', 'Demo Producer',
     1750, 1900, 'washed', 'light', current_date - 12, 2025, 88.5, 250, 'Delicate and floral.'),
    ('aaaaaaaa-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222',
     'Pink Bourbon Natural (demo)', 'Leo Roasts', 'CO', 'Antioquia', 'Finca El Mirador (demo)', 'Demo Producer',
     1800, 2000, 'natural', 'medium_light', current_date - 8, 2025, 87.0, 340, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO bean_varietals (bean_id, varietal_slug) VALUES
    ('aaaaaaaa-0000-4000-8000-000000000001', 'geisha'),
    ('aaaaaaaa-0000-4000-8000-000000000002', 'pink_bourbon')
ON CONFLICT DO NOTHING;

INSERT INTO bean_flavor_notes (bean_id, flavor_note_slug) VALUES
    ('aaaaaaaa-0000-4000-8000-000000000001', 'jasmine'),
    ('aaaaaaaa-0000-4000-8000-000000000001', 'bergamot'),
    ('aaaaaaaa-0000-4000-8000-000000000001', 'peach'),
    ('aaaaaaaa-0000-4000-8000-000000000002', 'strawberry'),
    ('aaaaaaaa-0000-4000-8000-000000000002', 'panela')
ON CONFLICT DO NOTHING;

INSERT INTO recipes
    (id, author_id, bean_id, method_slug, title, description, dose_g, water_g, yield_g, grind_size,
     grinder_slug, grind_setting, water_temp_c, bloom_water_g, bloom_time_s, total_time_s, filter_type,
     water_profile, water_tds_ppm, tds_percent, rating, visibility)
VALUES
    ('bbbbbbbb-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
     'aaaaaaaa-0000-4000-8000-000000000001', 'v60', 'Floral V60',
     'Gentle pours to keep the florals.', 15, 250, 215, 'medium_fine',
     'comandante_c40_mk4', '24 clicks', 93, 45, 45, 180, 'paper', 'Filtered water', 80, 1.38, 5, 'public'),
    ('bbbbbbbb-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222',
     'aaaaaaaa-0000-4000-8000-000000000002', 'espresso', 'Fruity espresso',
     NULL, 18, NULL, 40, 'fine',
     'niche_zero', '12', 93, NULL, NULL, 30, NULL, NULL, NULL, 9.5, 4, 'followers')
ON CONFLICT (id) DO NOTHING;

UPDATE recipes SET pressure_bar = 9 WHERE id = 'bbbbbbbb-0000-4000-8000-000000000002';

INSERT INTO recipe_steps (recipe_id, position, kind, start_s, water_target_g, instruction) VALUES
    ('bbbbbbbb-0000-4000-8000-000000000001', 1, 'bloom', 0, 45, 'Pour 45 g and swirl gently.'),
    ('bbbbbbbb-0000-4000-8000-000000000001', 2, 'pour', 45, 150, 'Slow spiral pour.'),
    ('bbbbbbbb-0000-4000-8000-000000000001', 3, 'pour', 90, 250, 'Center pour to the top.'),
    ('bbbbbbbb-0000-4000-8000-000000000001', 4, 'swirl', 120, NULL, 'Swirl once and let it draw down.')
ON CONFLICT DO NOTHING;

INSERT INTO recipe_flavor_notes (recipe_id, flavor_note_slug) VALUES
    ('bbbbbbbb-0000-4000-8000-000000000001', 'jasmine'),
    ('bbbbbbbb-0000-4000-8000-000000000001', 'peach'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'strawberry'),
    ('bbbbbbbb-0000-4000-8000-000000000002', 'milk_chocolate')
ON CONFLICT DO NOTHING;

-- Leo remixed Ana's V60 with his own bean, and saved the original.
INSERT INTO recipes
    (id, author_id, bean_id, forked_from_id, method_slug, title, description, dose_g, water_g, grind_size,
     water_temp_c, total_time_s, filter_type, rating, visibility)
VALUES
    ('bbbbbbbb-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222',
     'aaaaaaaa-0000-4000-8000-000000000002', 'bbbbbbbb-0000-4000-8000-000000000001', 'v60',
     'Floral V60, hotter', 'Same pours, 96 °C for a denser natural.', 15, 250, 'medium_fine',
     96, 200, 'paper', 4, 'public')
ON CONFLICT (id) DO NOTHING;

INSERT INTO recipe_saves (user_id, recipe_id) VALUES
    ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-0000-4000-8000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO posts (id, author_id, kind, body, recipe_id) VALUES
    ('cccccccc-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'recipe',
     'My go-to recipe for washed Geishas.', 'bbbbbbbb-0000-4000-8000-000000000001')
ON CONFLICT (id) DO NOTHING;

INSERT INTO post_likes (post_id, user_id) VALUES
    ('cccccccc-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222')
ON CONFLICT DO NOTHING;

INSERT INTO comments (id, post_id, author_id, parent_id, body) VALUES
    ('dddddddd-0000-4000-8000-000000000001', 'cccccccc-0000-4000-8000-000000000001',
     '22222222-2222-4222-8222-222222222222', NULL, 'What grind setting on the Comandante?'),
    ('dddddddd-0000-4000-8000-000000000002', 'cccccccc-0000-4000-8000-000000000001',
     '11111111-1111-4111-8111-111111111111', 'dddddddd-0000-4000-8000-000000000001', '24 clicks, then adjust by taste.')
ON CONFLICT (id) DO NOTHING;

-- What Ana sees in her notifications.
INSERT INTO notifications (recipient_id, actor_id, kind, post_id, comment_id, recipe_id) VALUES
    ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'follow', NULL, NULL, NULL),
    ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'recipe_save', NULL, NULL,
     'bbbbbbbb-0000-4000-8000-000000000001'),
    ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'post_like',
     'cccccccc-0000-4000-8000-000000000001', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO notifications (recipient_id, actor_id, kind, post_id, comment_id)
SELECT '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'comment',
       'cccccccc-0000-4000-8000-000000000001', 'dddddddd-0000-4000-8000-000000000001'
WHERE NOT EXISTS (SELECT 1 FROM notifications WHERE comment_id = 'dddddddd-0000-4000-8000-000000000001');

INSERT INTO notifications (recipient_id, actor_id, kind, recipe_id)
SELECT '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'recipe_fork',
       'bbbbbbbb-0000-4000-8000-000000000003'
WHERE NOT EXISTS (SELECT 1 FROM notifications
                  WHERE kind = 'recipe_fork' AND recipe_id = 'bbbbbbbb-0000-4000-8000-000000000003');

COMMIT;
