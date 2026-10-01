BEGIN;
SELECT pg_temp.create_fixture_users();

INSERT INTO auth_identities (user_id, provider, subject) VALUES
    ('00000000-0000-0000-0000-00000000000a', 'google', 'google-test-subject'),
    ('00000000-0000-0000-0000-00000000000b', 'apple', 'apple-test-subject');
SELECT pg_temp.expect_error($$
    INSERT INTO auth_identities (user_id, provider, subject) VALUES
    ('00000000-0000-0000-0000-00000000000e', 'google', 'google-test-subject')
$$, '23505');
SELECT pg_temp.expect_error($$
    INSERT INTO auth_identities (user_id, provider, subject, password_hash) VALUES
    ('00000000-0000-0000-0000-00000000000e', 'google', 'another-google-subject', 'invalid')
$$, '23514');
SELECT pg_temp.expect_error($$
    UPDATE auth_identities SET provider_refresh_token = 'invalid'
    WHERE provider = 'google' AND subject = 'google-test-subject'
$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO auth_challenges (provider, nonce_hash, expires_at)
    VALUES ('password', repeat('a', 64), now() + interval '5 minutes')
$$, '23514');
SELECT pg_temp.expect_error($$
    INSERT INTO auth_challenges (provider, nonce_hash, expires_at)
    VALUES ('google', 'plain-nonce', now() + interval '5 minutes')
$$, '23514');
DELETE FROM users WHERE id = '00000000-0000-0000-0000-00000000000a';
SELECT pg_temp.expect_equal((SELECT count(*) FROM auth_identities WHERE subject = 'google-test-subject'),
    0::bigint, 'Deleting a member cascades to Google identity');
ROLLBACK;
