-- migrate:up

-- Keeps `updated_at` columns current on every UPDATE.
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Domains act as reusable, easy-to-evolve enumerations.
-- Clients see them as plain `text` on the wire.
CREATE DOMAIN visibility AS text
    CHECK (VALUE IN ('public', 'followers', 'private'));
COMMENT ON DOMAIN visibility IS 'Who can see a piece of content: everyone, followers of the owner, or only the owner.';

CREATE DOMAIN roast_level AS text
    CHECK (VALUE IN ('light', 'medium_light', 'medium', 'medium_dark', 'dark'));

CREATE DOMAIN grind_size AS text
    CHECK (VALUE IN ('extra_fine', 'fine', 'medium_fine', 'medium', 'medium_coarse', 'coarse', 'extra_coarse'));
COMMENT ON DOMAIN grind_size IS 'Grinder-independent grind descriptor, from Turkish (extra_fine) to cold brew (extra_coarse).';

-- migrate:down

DROP DOMAIN grind_size;
DROP DOMAIN roast_level;
DROP DOMAIN visibility;
DROP FUNCTION set_updated_at();
