-- Personal details, onboarding and Sign in with Apple fields.
BEGIN;
SELECT pg_temp.create_fixture_users();

-- Fixture users have no private details yet, so they still need onboarding.
SELECT pg_temp.expect_equal((SELECT count(*) FROM users WHERE onboarding_completed_at IS NULL),
                            3::bigint, 'fixture users need onboarding');
SELECT pg_temp.expect_equal((SELECT role FROM users WHERE id = '00000000-0000-0000-0000-00000000000a'),
                            'user', 'default role');

-- Onboarding can only be completed with names, birth date and accepted terms.
SELECT pg_temp.expect_error($$
    UPDATE users SET onboarding_completed_at = now()
    WHERE id = '00000000-0000-0000-0000-00000000000a'$$, '23514');
UPDATE users
SET first_name = 'Ana', last_name = 'Rojas', birth_date = '1995-04-12', country_code = 'CO', city = 'Bogotá',
    terms_accepted_at = now(), onboarding_completed_at = now()
WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal((SELECT onboarding_completed_at IS NOT NULL FROM users
                             WHERE id = '00000000-0000-0000-0000-00000000000a'), true, 'onboarding completed');
SELECT pg_temp.expect_error($$
    UPDATE users SET birth_date = NULL WHERE id = '00000000-0000-0000-0000-00000000000a'$$, '23514');

-- Formats and ranges.
SELECT pg_temp.expect_error($$
    UPDATE users SET first_name = '' WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE users SET last_name = repeat('x', 61) WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE users SET birth_date = '1899-12-31' WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE users SET country_code = 'co' WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE users SET city = repeat('x', 81) WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE users SET role = 'owner' WHERE id = '00000000-0000-0000-0000-00000000000b'$$, '23514');

-- Any country of residence is allowed, not only coffee origins.
UPDATE users SET country_code = 'DE' WHERE id = '00000000-0000-0000-0000-00000000000b';

-- Provider fields belong to Sign in with Apple identities only.
SELECT pg_temp.expect_error($$
    INSERT INTO auth_identities (user_id, provider, subject, password_hash, provider_email)
    VALUES ('00000000-0000-0000-0000-00000000000e', 'password', 'eve@example.com', 'hash', 'eve@example.com')$$,
    '23514');
INSERT INTO auth_identities (user_id, provider, subject, provider_refresh_token, provider_email)
VALUES ('00000000-0000-0000-0000-00000000000e', 'apple', '000123.abc', 'encrypted', 'x@privaterelay.appleid.com');

ROLLBACK;
