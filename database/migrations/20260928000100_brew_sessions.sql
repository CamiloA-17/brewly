-- migrate:up

-- A recipe is reusable; each brew is an observation of one attempt.
-- Snapshots preserve the journal if its recipe is later edited or deleted.
CREATE TABLE brew_sessions (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipe_id        uuid,
    recipe_title     text        NOT NULL,
    bean_name        text        NOT NULL,
    method_slug      text        NOT NULL REFERENCES brew_methods (slug) ON UPDATE CASCADE,
    dose_g           numeric(5,1) NOT NULL,
    water_g          numeric(6,1),
    yield_g          numeric(6,1),
    grind_setting    text,
    water_temp_c     numeric(4,1),
    elapsed_s        integer     NOT NULL,
    rating           smallint,
    acidity          smallint,
    bitterness       smallint,
    body             smallint,
    notes            text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT brew_sessions_recipe_owned_by_user FOREIGN KEY (recipe_id, user_id)
        REFERENCES recipes (id, author_id) ON DELETE SET NULL (recipe_id),
    CONSTRAINT brew_sessions_recipe_title_check CHECK (char_length(recipe_title) BETWEEN 1 AND 120),
    CONSTRAINT brew_sessions_bean_name_check CHECK (char_length(bean_name) BETWEEN 1 AND 120),
    CONSTRAINT brew_sessions_dose_check CHECK (dose_g > 0 AND dose_g <= 1000),
    CONSTRAINT brew_sessions_water_check CHECK (water_g IS NULL OR water_g > 0 AND water_g <= 10000),
    CONSTRAINT brew_sessions_yield_check CHECK (yield_g IS NULL OR yield_g > 0 AND yield_g <= 10000),
    CONSTRAINT brew_sessions_grind_setting_check CHECK (grind_setting IS NULL OR char_length(grind_setting) <= 40),
    CONSTRAINT brew_sessions_temperature_check CHECK (water_temp_c IS NULL OR water_temp_c BETWEEN 0 AND 100),
    CONSTRAINT brew_sessions_elapsed_check CHECK (elapsed_s BETWEEN 0 AND 172800),
    CONSTRAINT brew_sessions_rating_check CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    CONSTRAINT brew_sessions_acidity_check CHECK (acidity IS NULL OR acidity BETWEEN 1 AND 5),
    CONSTRAINT brew_sessions_bitterness_check CHECK (bitterness IS NULL OR bitterness BETWEEN 1 AND 5),
    CONSTRAINT brew_sessions_body_check CHECK (body IS NULL OR body BETWEEN 1 AND 5),
    CONSTRAINT brew_sessions_notes_check CHECK (notes IS NULL OR char_length(notes) <= 2000)
);
COMMENT ON TABLE brew_sessions IS 'Actual brews with their own measurements and tasting results, independent of mutable recipe templates.';
CREATE INDEX brew_sessions_user_created_idx ON brew_sessions (user_id, created_at DESC, id DESC);
CREATE INDEX brew_sessions_recipe_created_idx ON brew_sessions (recipe_id, created_at DESC, id DESC);
CREATE INDEX brew_sessions_method_idx ON brew_sessions (method_slug);

-- Old recipes stored both the plan and its result. Preserve result-bearing rows
-- as the first recorded session; a recipe without a result remains only a plan.
INSERT INTO brew_sessions
    (user_id, recipe_id, recipe_title, bean_name, method_slug, dose_g, water_g,
     yield_g, grind_setting, water_temp_c, elapsed_s, rating, notes, created_at)
SELECT r.author_id, r.id, r.title, b.name, r.method_slug, r.dose_g, r.water_g,
       r.yield_g, r.grind_setting, r.water_temp_c, coalesce(r.total_time_s, 0),
       r.rating, r.notes, r.created_at
FROM recipes r JOIN coffee_beans b ON b.id = r.bean_id
WHERE r.rating IS NOT NULL OR r.notes IS NOT NULL OR r.tds_percent IS NOT NULL;

-- migrate:down

DROP TABLE brew_sessions;
