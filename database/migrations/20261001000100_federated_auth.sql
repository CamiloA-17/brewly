-- migrate:up

ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('password', 'apple', 'google'));
COMMENT ON COLUMN auth_identities.subject IS
    'Normalized email for password; stable, case-sensitive provider sub for Apple and Google.';
CREATE INDEX auth_identities_user_id_idx ON auth_identities (user_id);

CREATE TABLE auth_challenges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider text NOT NULL,
    nonce_hash text NOT NULL,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT auth_challenges_provider_check CHECK (provider IN ('apple', 'google')),
    CONSTRAINT auth_challenges_nonce_hash_format CHECK (nonce_hash ~ '^[a-f0-9]{64}$')
);
CREATE INDEX auth_challenges_expires_at_idx ON auth_challenges (expires_at);
COMMENT ON TABLE auth_challenges IS
    'Short-lived, single-use server nonces binding provider ID tokens to a sign-in attempt.';

-- migrate:down

DROP TABLE auth_challenges;
DROP INDEX auth_identities_user_id_idx;
-- A rollback with Google members must fail rather than destroy their identities.
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_provider_check;
ALTER TABLE auth_identities ADD CONSTRAINT auth_identities_provider_check
    CHECK (provider IN ('password', 'apple'));
COMMENT ON COLUMN auth_identities.subject IS
    'Normalized email for "password", Apple user identifier (sub) for "apple".';
