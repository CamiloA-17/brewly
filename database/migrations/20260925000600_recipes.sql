-- migrate:up

-- A recipe is a preparation: every parameter a barista needs to reproduce a cup.
CREATE TABLE recipes (
    id                        uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id                 uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    bean_id                   uuid         NOT NULL,
    method_slug               text         NOT NULL REFERENCES brew_methods (slug) ON UPDATE CASCADE,
    forked_from_id            uuid         REFERENCES recipes (id) ON DELETE SET NULL,
    title                     text         NOT NULL,
    description               text,

    -- Dosing. Filter methods use water_g; espresso uses yield_g (beverage weight).
    dose_g                    numeric(5,1) NOT NULL,
    water_g                   numeric(6,1),
    yield_g                   numeric(6,1),
    ratio                     numeric(5,2) GENERATED ALWAYS AS
                                  (round(coalesce(water_g, yield_g) / nullif(dose_g, 0), 2)) STORED,

    -- Grind.
    grind_size                grind_size   NOT NULL,
    grinder_slug              text         REFERENCES grinders (slug) ON UPDATE CASCADE,
    grind_setting             text,
    grind_microns             integer,

    -- Extraction.
    water_temp_c              numeric(4,1),
    bloom_water_g             numeric(5,1),
    bloom_time_s              integer,
    total_time_s              integer,
    pressure_bar              numeric(3,1),
    filter_type               text,

    -- Water.
    water_profile             text,
    water_tds_ppm             integer,

    -- Results.
    tds_percent               numeric(4,2),
    extraction_yield_percent  numeric(5,2) GENERATED ALWAYS AS
                                  (round(yield_g * tds_percent / nullif(dose_g, 0), 2)) STORED,
    rating                    smallint,
    notes                     text,

    visibility                visibility   NOT NULL DEFAULT 'public',
    created_at                timestamptz  NOT NULL DEFAULT now(),
    updated_at                timestamptz  NOT NULL DEFAULT now(),

    -- A recipe can only use a bean owned by its author.
    CONSTRAINT recipes_bean_owned_by_author FOREIGN KEY (bean_id, author_id)
        REFERENCES coffee_beans (id, owner_id),
    -- Target of composite foreign keys that guarantee ownership (posts).
    CONSTRAINT recipes_id_author_key UNIQUE (id, author_id),

    CONSTRAINT recipes_title_length CHECK (char_length(title) BETWEEN 1 AND 120),
    CONSTRAINT recipes_description_length CHECK (description IS NULL OR char_length(description) <= 2000),
    CONSTRAINT recipes_dose_check CHECK (dose_g > 0 AND dose_g <= 1000),
    CONSTRAINT recipes_water_check CHECK (water_g IS NULL OR (water_g > 0 AND water_g <= 10000)),
    CONSTRAINT recipes_yield_check CHECK (yield_g IS NULL OR (yield_g > 0 AND yield_g <= 10000)),
    CONSTRAINT recipes_water_or_yield CHECK (water_g IS NOT NULL OR yield_g IS NOT NULL),
    CONSTRAINT recipes_ratio_range CHECK (coalesce(water_g, yield_g) / nullif(dose_g, 0) BETWEEN 0.5 AND 50),
    CONSTRAINT recipes_grind_setting_length CHECK (grind_setting IS NULL OR char_length(grind_setting) <= 40),
    CONSTRAINT recipes_grind_microns_check CHECK (grind_microns IS NULL OR grind_microns BETWEEN 50 AND 2000),
    CONSTRAINT recipes_water_temp_check CHECK (water_temp_c IS NULL OR water_temp_c BETWEEN 0 AND 100),
    CONSTRAINT recipes_bloom_water_check CHECK (bloom_water_g IS NULL OR bloom_water_g > 0),
    CONSTRAINT recipes_bloom_within_water CHECK (bloom_water_g IS NULL OR water_g IS NULL OR bloom_water_g <= water_g),
    CONSTRAINT recipes_bloom_time_check CHECK (bloom_time_s IS NULL OR bloom_time_s BETWEEN 0 AND 600),
    CONSTRAINT recipes_total_time_check CHECK (total_time_s IS NULL OR total_time_s BETWEEN 1 AND 172800),
    CONSTRAINT recipes_pressure_check CHECK (pressure_bar IS NULL OR (pressure_bar > 0 AND pressure_bar <= 20)),
    CONSTRAINT recipes_filter_type_check CHECK (filter_type IS NULL OR filter_type IN ('paper', 'metal', 'cloth')),
    CONSTRAINT recipes_water_profile_length CHECK (water_profile IS NULL OR char_length(water_profile) <= 120),
    CONSTRAINT recipes_water_tds_check CHECK (water_tds_ppm IS NULL OR water_tds_ppm BETWEEN 0 AND 1000),
    CONSTRAINT recipes_tds_check CHECK (tds_percent IS NULL OR (tds_percent > 0 AND tds_percent <= 25)),
    CONSTRAINT recipes_rating_check CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    CONSTRAINT recipes_notes_length CHECK (notes IS NULL OR char_length(notes) <= 2000)
);
COMMENT ON COLUMN recipes.ratio IS
    'Brew ratio (1:N). Uses water_g when present (filter methods), otherwise yield_g (espresso).';
COMMENT ON COLUMN recipes.extraction_yield_percent IS 'EY% = beverage weight x TDS% / dose.';
COMMENT ON COLUMN recipes.grind_setting IS 'Grinder-specific setting, e.g. "24 clicks" or "3.5".';

CREATE INDEX recipes_author_created_idx ON recipes (author_id, created_at DESC, id DESC);
CREATE INDEX recipes_public_created_idx ON recipes (created_at DESC, id DESC) WHERE visibility = 'public';
CREATE INDEX recipes_method_created_idx ON recipes (method_slug, created_at DESC);
CREATE INDEX recipes_bean_idx ON recipes (bean_id);
CREATE INDEX recipes_grinder_idx ON recipes (grinder_slug);
CREATE INDEX recipes_forked_from_idx ON recipes (forked_from_id);

CREATE TRIGGER recipes_set_updated_at
    BEFORE UPDATE ON recipes
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Ordered brewing steps (pour schedule).
CREATE TABLE recipe_steps (
    recipe_id       uuid         NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    position        smallint     NOT NULL,
    kind            text         NOT NULL,
    start_s         integer      NOT NULL DEFAULT 0,
    water_target_g  numeric(6,1),
    instruction     text,
    PRIMARY KEY (recipe_id, position),
    CONSTRAINT recipe_steps_position_check CHECK (position BETWEEN 1 AND 50),
    CONSTRAINT recipe_steps_kind_check CHECK (kind IN
        ('bloom', 'pour', 'stir', 'swirl', 'wait', 'press', 'invert', 'other')),
    CONSTRAINT recipe_steps_start_check CHECK (start_s >= 0),
    CONSTRAINT recipe_steps_water_target_check CHECK (water_target_g IS NULL OR water_target_g > 0),
    CONSTRAINT recipe_steps_instruction_length CHECK (instruction IS NULL OR char_length(instruction) <= 280)
);
COMMENT ON COLUMN recipe_steps.water_target_g IS 'Cumulative scale reading to reach during this step.';

-- Tasting notes perceived in the cup.
CREATE TABLE recipe_flavor_notes (
    recipe_id         uuid NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    flavor_note_slug  text NOT NULL REFERENCES flavor_notes (slug) ON UPDATE CASCADE,
    PRIMARY KEY (recipe_id, flavor_note_slug)
);
CREATE INDEX recipe_flavor_notes_flavor_note_idx ON recipe_flavor_notes (flavor_note_slug);

-- Recipes bookmarked by users.
CREATE TABLE recipe_saves (
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id   uuid        NOT NULL REFERENCES recipes (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);
CREATE INDEX recipe_saves_recipe_idx ON recipe_saves (recipe_id);

-- Brew methods from the global catalog that each user owns or uses.
CREATE TABLE user_brew_methods (
    user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    method_slug  text        NOT NULL REFERENCES brew_methods (slug) ON UPDATE CASCADE,
    created_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, method_slug)
);
CREATE INDEX user_brew_methods_method_idx ON user_brew_methods (method_slug);

-- migrate:down

DROP TABLE user_brew_methods;
DROP TABLE recipe_saves;
DROP TABLE recipe_flavor_notes;
DROP TABLE recipe_steps;
DROP TABLE recipes;
