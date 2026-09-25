-- migrate:up

-- A coffee owned by a user: typically one bag, from farm to roast.
CREATE TABLE coffee_beans (
    id                      uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id                uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name                    text         NOT NULL,
    roaster                 text,
    country_code            char(2)      REFERENCES countries (code) ON UPDATE CASCADE,
    region                  text,
    farm                    text,
    producer                text,
    altitude_min_m          integer,
    altitude_max_m          integer,
    processing_method_slug  text         REFERENCES processing_methods (slug) ON UPDATE CASCADE,
    roast_level             roast_level,
    roast_date              date,
    harvest_year            smallint,
    sca_score               numeric(4,2),
    weight_g                integer,
    is_decaf                boolean      NOT NULL DEFAULT false,
    notes                   text,
    photo_url               text,
    visibility              visibility   NOT NULL DEFAULT 'public',
    archived_at             timestamptz,
    created_at              timestamptz  NOT NULL DEFAULT now(),
    updated_at              timestamptz  NOT NULL DEFAULT now(),
    -- Target of composite foreign keys that guarantee ownership (recipes, posts).
    CONSTRAINT coffee_beans_id_owner_key UNIQUE (id, owner_id),
    CONSTRAINT coffee_beans_name_length CHECK (char_length(name) BETWEEN 1 AND 120),
    CONSTRAINT coffee_beans_roaster_length CHECK (roaster IS NULL OR char_length(roaster) <= 120),
    CONSTRAINT coffee_beans_region_length CHECK (region IS NULL OR char_length(region) <= 120),
    CONSTRAINT coffee_beans_farm_length CHECK (farm IS NULL OR char_length(farm) <= 120),
    CONSTRAINT coffee_beans_producer_length CHECK (producer IS NULL OR char_length(producer) <= 120),
    CONSTRAINT coffee_beans_altitude_min_check CHECK (altitude_min_m IS NULL OR altitude_min_m BETWEEN 0 AND 3500),
    CONSTRAINT coffee_beans_altitude_max_check CHECK (altitude_max_m IS NULL OR altitude_max_m BETWEEN 0 AND 3500),
    CONSTRAINT coffee_beans_altitude_range CHECK (
        altitude_min_m IS NULL OR altitude_max_m IS NULL OR altitude_min_m <= altitude_max_m),
    CONSTRAINT coffee_beans_harvest_year_check CHECK (harvest_year IS NULL OR harvest_year BETWEEN 1900 AND 2100),
    CONSTRAINT coffee_beans_sca_score_check CHECK (sca_score IS NULL OR sca_score BETWEEN 0 AND 100),
    CONSTRAINT coffee_beans_weight_check CHECK (weight_g IS NULL OR weight_g BETWEEN 1 AND 100000),
    CONSTRAINT coffee_beans_notes_length CHECK (notes IS NULL OR char_length(notes) <= 2000)
);
COMMENT ON COLUMN coffee_beans.archived_at IS 'Set when the bag is finished; archived beans stay referenced by recipes.';

CREATE INDEX coffee_beans_owner_created_idx ON coffee_beans (owner_id, created_at DESC);
CREATE INDEX coffee_beans_country_idx ON coffee_beans (country_code);
CREATE INDEX coffee_beans_processing_method_idx ON coffee_beans (processing_method_slug);

CREATE TRIGGER coffee_beans_set_updated_at
    BEFORE UPDATE ON coffee_beans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- A bean can be a single varietal or a blend of several.
CREATE TABLE bean_varietals (
    bean_id        uuid NOT NULL REFERENCES coffee_beans (id) ON DELETE CASCADE,
    varietal_slug  text NOT NULL REFERENCES varietals (slug) ON UPDATE CASCADE,
    PRIMARY KEY (bean_id, varietal_slug)
);
CREATE INDEX bean_varietals_varietal_idx ON bean_varietals (varietal_slug);

-- Tasting notes declared by the roaster or producer.
CREATE TABLE bean_flavor_notes (
    bean_id           uuid NOT NULL REFERENCES coffee_beans (id) ON DELETE CASCADE,
    flavor_note_slug  text NOT NULL REFERENCES flavor_notes (slug) ON UPDATE CASCADE,
    PRIMARY KEY (bean_id, flavor_note_slug)
);
CREATE INDEX bean_flavor_notes_flavor_note_idx ON bean_flavor_notes (flavor_note_slug);

-- migrate:down

DROP TABLE bean_flavor_notes;
DROP TABLE bean_varietals;
DROP TABLE coffee_beans;
