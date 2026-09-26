-- migrate:up

-- Personal details, collected at sign-up (email) or in onboarding (Sign in with Apple, or
-- accounts created before this migration). First name, last name and birth date are private:
-- only the member sees them.
ALTER TABLE users RENAME COLUMN location TO city;
ALTER TABLE users RENAME CONSTRAINT users_location_length TO users_city_length;

ALTER TABLE users
    ADD COLUMN first_name              text,
    ADD COLUMN last_name               text,
    ADD COLUMN birth_date              date,
    ADD COLUMN country_code            char(2),
    ADD COLUMN role                    text        NOT NULL DEFAULT 'user',
    ADD COLUMN terms_accepted_at       timestamptz,
    ADD COLUMN onboarding_completed_at timestamptz,
    ADD COLUMN last_seen_at            timestamptz,
    ADD COLUMN deactivated_at          timestamptz,
    ADD CONSTRAINT users_first_name_length CHECK (first_name IS NULL OR char_length(first_name) BETWEEN 1 AND 60),
    ADD CONSTRAINT users_last_name_length CHECK (last_name IS NULL OR char_length(last_name) BETWEEN 1 AND 60),
    -- The minimum age (13) depends on the current date, so the API enforces it.
    ADD CONSTRAINT users_birth_date_check CHECK (birth_date IS NULL OR birth_date >= DATE '1900-01-01'),
    ADD CONSTRAINT users_country_code_format CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
    ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin')),
    ADD CONSTRAINT users_onboarding_complete CHECK (
        onboarding_completed_at IS NULL
        OR (first_name IS NOT NULL AND last_name IS NOT NULL AND birth_date IS NOT NULL
            AND terms_accepted_at IS NOT NULL));

COMMENT ON COLUMN users.city IS 'Optional, public.';
COMMENT ON COLUMN users.country_code IS
    'Country of residence (ISO 3166-1 alpha-2). Not tied to the coffee-origin countries catalog.';
COMMENT ON COLUMN users.birth_date IS 'Private. Members must be at least 13 years old (checked by the API).';
COMMENT ON COLUMN users.role IS '"admin" members can review reports.';
COMMENT ON COLUMN users.onboarding_completed_at IS
    'Set once the private details are filled in; until then the app shows the onboarding screen.';
COMMENT ON COLUMN users.last_seen_at IS 'Updated when the member signs in or refreshes a session.';
COMMENT ON COLUMN users.deactivated_at IS 'Reserved for account deactivation.';

-- Sign in with Apple: the refresh token Apple issues (encrypted by the API) is needed to revoke
-- the authorization when the account is deleted; the email may be a private relay address.
ALTER TABLE auth_identities
    ADD COLUMN provider_refresh_token text,
    ADD COLUMN provider_email         text,
    ADD CONSTRAINT auth_identities_provider_fields_check CHECK (
        provider = 'apple' OR (provider_refresh_token IS NULL AND provider_email IS NULL));

COMMENT ON COLUMN auth_identities.provider_refresh_token IS 'Apple refresh token, encrypted by the API.';
COMMENT ON COLUMN auth_identities.provider_email IS 'Email shared by Apple, possibly a private relay address.';

-- migrate:down

ALTER TABLE auth_identities
    DROP CONSTRAINT auth_identities_provider_fields_check,
    DROP COLUMN provider_email,
    DROP COLUMN provider_refresh_token;

ALTER TABLE users
    DROP CONSTRAINT users_onboarding_complete,
    DROP CONSTRAINT users_role_check,
    DROP CONSTRAINT users_country_code_format,
    DROP CONSTRAINT users_birth_date_check,
    DROP CONSTRAINT users_last_name_length,
    DROP CONSTRAINT users_first_name_length,
    DROP COLUMN deactivated_at,
    DROP COLUMN last_seen_at,
    DROP COLUMN onboarding_completed_at,
    DROP COLUMN terms_accepted_at,
    DROP COLUMN role,
    DROP COLUMN country_code,
    DROP COLUMN birth_date,
    DROP COLUMN last_name,
    DROP COLUMN first_name;

COMMENT ON COLUMN users.city IS NULL;
ALTER TABLE users RENAME CONSTRAINT users_city_length TO users_location_length;
ALTER TABLE users RENAME COLUMN city TO location;
