-- migrate:up

CREATE TABLE users (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    username      text        NOT NULL,
    display_name  text        NOT NULL,
    email         text,
    bio           text,
    avatar_url    text,
    location      text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_username_key UNIQUE (username),
    CONSTRAINT users_email_key UNIQUE (email),
    CONSTRAINT users_username_format CHECK (username ~ '^[a-z0-9_.]{3,30}$'),
    CONSTRAINT users_display_name_length CHECK (char_length(display_name) BETWEEN 1 AND 60),
    CONSTRAINT users_email_normalized CHECK (email IS NULL OR (email = lower(email) AND email LIKE '%_@_%')),
    CONSTRAINT users_bio_length CHECK (bio IS NULL OR char_length(bio) <= 300),
    CONSTRAINT users_location_length CHECK (location IS NULL OR char_length(location) <= 80)
);
COMMENT ON TABLE users IS 'Public profile of every Brewly member.';
COMMENT ON COLUMN users.username IS 'Unique handle, stored lowercase.';

CREATE TRIGGER users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- One row per way a user can sign in (email + password today, Sign in with Apple next).
CREATE TABLE auth_identities (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    provider       text        NOT NULL,
    subject        text        NOT NULL,
    password_hash  text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT auth_identities_provider_check CHECK (provider IN ('password', 'apple')),
    CONSTRAINT auth_identities_provider_subject_key UNIQUE (provider, subject),
    CONSTRAINT auth_identities_user_provider_key UNIQUE (user_id, provider),
    CONSTRAINT auth_identities_password_hash_check CHECK ((provider = 'password') = (password_hash IS NOT NULL))
);
COMMENT ON COLUMN auth_identities.subject IS 'Normalized email for "password", Apple user identifier (sub) for "apple".';

-- Opaque, rotating refresh tokens. Only a SHA-256 hash is stored.
CREATE TABLE refresh_tokens (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash  text        NOT NULL,
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT refresh_tokens_token_hash_key UNIQUE (token_hash)
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens (user_id);

-- migrate:down

DROP TABLE refresh_tokens;
DROP TABLE auth_identities;
DROP TABLE users;
