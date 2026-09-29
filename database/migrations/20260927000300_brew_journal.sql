-- migrate:up

-- How much coffee is left in each bag. Brews consume it; the member can also adjust it.
ALTER TABLE coffee_beans
    ADD COLUMN remaining_g numeric(7,1),
    ADD CONSTRAINT coffee_beans_remaining_check CHECK (remaining_g IS NULL OR remaining_g BETWEEN 0 AND 100000);
COMMENT ON COLUMN coffee_beans.remaining_g IS 'Coffee left in the bag. Starts at weight_g; each brew subtracts its dose.';
UPDATE coffee_beans SET remaining_g = weight_g WHERE weight_g IS NOT NULL;

-- The brew journal: every cup a member prepares, with the parameters actually used and how it
-- tasted. A brew may follow a recipe (the member's or a visible one of someone else) or not.
CREATE TABLE brew_logs (
    id                        uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                   uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id                 uuid         REFERENCES recipes (id) ON DELETE SET NULL,
    bean_id                   uuid         NOT NULL,
    method_slug               text         NOT NULL REFERENCES brew_methods (slug) ON UPDATE CASCADE,
    equipment_id              uuid,
    brewed_at                 timestamptz  NOT NULL DEFAULT now(),

    -- Parameters actually used. Same meaning and limits as in recipes.
    dose_g                    numeric(5,1) NOT NULL,
    water_g                   numeric(6,1),
    yield_g                   numeric(6,1),
    ratio                     numeric(5,2) GENERATED ALWAYS AS
                                  (round(coalesce(water_g, yield_g) / nullif(dose_g, 0), 2)) STORED,
    grind_size                grind_size,
    grind_setting             text,
    water_temp_c              numeric(4,1),
    total_time_s              integer,

    -- Tasting, each from 1 to 5.
    rating                    smallint,
    acidity                   smallint,
    sweetness                 smallint,
    body                      smallint,
    bitterness                smallint,
    aftertaste                smallint,
    tds_percent               numeric(4,2),
    extraction_yield_percent  numeric(5,2) GENERATED ALWAYS AS
                                  (round(yield_g * tds_percent / nullif(dose_g, 0), 2)) STORED,
    notes                     text,
    photo_media_id            uuid         REFERENCES media (id) ON DELETE SET NULL,

    -- A journal is personal: brews are private unless the member shares them.
    visibility                visibility   NOT NULL DEFAULT 'private',
    created_at                timestamptz  NOT NULL DEFAULT now(),
    updated_at                timestamptz  NOT NULL DEFAULT now(),

    -- A brew only uses the member's own bean and equipment. A bean with brews can't be
    -- deleted (archive it instead); deleted equipment is simply forgotten.
    CONSTRAINT brew_logs_bean_owned_by_user FOREIGN KEY (bean_id, user_id)
        REFERENCES coffee_beans (id, owner_id),
    CONSTRAINT brew_logs_equipment_owned_by_user FOREIGN KEY (equipment_id, user_id)
        REFERENCES user_equipment (id, owner_id) ON DELETE SET NULL (equipment_id),
    -- Target of composite foreign keys that guarantee ownership (posts).
    CONSTRAINT brew_logs_id_user_key UNIQUE (id, user_id),
    -- Each uploaded photo illustrates a single brew.
    CONSTRAINT brew_logs_photo_media_key UNIQUE (photo_media_id),

    CONSTRAINT brew_logs_dose_check CHECK (dose_g > 0 AND dose_g <= 1000),
    CONSTRAINT brew_logs_water_check CHECK (water_g IS NULL OR (water_g > 0 AND water_g <= 10000)),
    CONSTRAINT brew_logs_yield_check CHECK (yield_g IS NULL OR (yield_g > 0 AND yield_g <= 10000)),
    CONSTRAINT brew_logs_water_or_yield CHECK (water_g IS NOT NULL OR yield_g IS NOT NULL),
    CONSTRAINT brew_logs_ratio_range CHECK (coalesce(water_g, yield_g) / nullif(dose_g, 0) BETWEEN 0.5 AND 50),
    CONSTRAINT brew_logs_grind_setting_length CHECK (grind_setting IS NULL OR char_length(grind_setting) <= 40),
    CONSTRAINT brew_logs_water_temp_check CHECK (water_temp_c IS NULL OR water_temp_c BETWEEN 0 AND 100),
    CONSTRAINT brew_logs_total_time_check CHECK (total_time_s IS NULL OR total_time_s BETWEEN 1 AND 172800),
    CONSTRAINT brew_logs_tds_check CHECK (tds_percent IS NULL OR (tds_percent > 0 AND tds_percent <= 25)),
    CONSTRAINT brew_logs_tasting_check CHECK (
        (rating IS NULL OR rating BETWEEN 1 AND 5)
        AND (acidity IS NULL OR acidity BETWEEN 1 AND 5)
        AND (sweetness IS NULL OR sweetness BETWEEN 1 AND 5)
        AND (body IS NULL OR body BETWEEN 1 AND 5)
        AND (bitterness IS NULL OR bitterness BETWEEN 1 AND 5)
        AND (aftertaste IS NULL OR aftertaste BETWEEN 1 AND 5)),
    CONSTRAINT brew_logs_notes_length CHECK (notes IS NULL OR char_length(notes) <= 2000)
);
COMMENT ON TABLE brew_logs IS 'The brew journal: each cup prepared, with its real parameters and tasting.';
COMMENT ON COLUMN brew_logs.recipe_id IS 'The recipe followed, if any; kept as NULL when the recipe is deleted.';

CREATE INDEX brew_logs_user_brewed_idx ON brew_logs (user_id, brewed_at DESC, id DESC);
CREATE INDEX brew_logs_bean_idx ON brew_logs (bean_id);
CREATE INDEX brew_logs_recipe_idx ON brew_logs (recipe_id);
CREATE INDEX brew_logs_method_idx ON brew_logs (method_slug);
CREATE INDEX brew_logs_equipment_idx ON brew_logs (equipment_id);

CREATE TRIGGER brew_logs_set_updated_at
    BEFORE UPDATE ON brew_logs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Tasting notes perceived in the cup.
CREATE TABLE brew_log_flavor_notes (
    brew_log_id       uuid NOT NULL REFERENCES brew_logs (id) ON DELETE CASCADE,
    flavor_note_slug  text NOT NULL REFERENCES flavor_notes (slug) ON UPDATE CASCADE,
    PRIMARY KEY (brew_log_id, flavor_note_slug)
);
CREATE INDEX brew_log_flavor_notes_flavor_note_idx ON brew_log_flavor_notes (flavor_note_slug);

-- migrate:down

DROP TABLE brew_log_flavor_notes;
DROP TABLE brew_logs;
ALTER TABLE coffee_beans
    DROP CONSTRAINT coffee_beans_remaining_check,
    DROP COLUMN remaining_g;
