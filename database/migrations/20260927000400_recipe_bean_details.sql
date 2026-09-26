-- migrate:up

-- Results belong to each cup, so they move from recipes to the brew journal. Existing results
-- become the author's first brew of the recipe.
INSERT INTO brew_logs
    (user_id, recipe_id, bean_id, method_slug, brewed_at, dose_g, water_g, yield_g, grind_size,
     grind_setting, water_temp_c, total_time_s, rating, tds_percent, visibility)
SELECT author_id, id, bean_id, method_slug, created_at, dose_g, water_g, yield_g, grind_size,
       grind_setting, water_temp_c, total_time_s, rating, tds_percent, 'private'
FROM recipes
WHERE rating IS NOT NULL OR tds_percent IS NOT NULL;

ALTER TABLE recipes
    DROP COLUMN extraction_yield_percent,
    DROP COLUMN tds_percent,
    DROP COLUMN rating;

-- What a recipe serves and how: cups, ice for iced pour-overs, and milk drinks built on espresso.
ALTER TABLE recipes
    ADD COLUMN cover_media_id uuid REFERENCES media (id) ON DELETE SET NULL,
    ADD COLUMN servings       smallint,
    ADD COLUMN ice_g          numeric(6,1),
    ADD COLUMN drink_type     text,
    ADD COLUMN milk_g         numeric(6,1),
    ADD COLUMN brewer_detail  text,
    ADD CONSTRAINT recipes_cover_media_key UNIQUE (cover_media_id),
    ADD CONSTRAINT recipes_servings_check CHECK (servings IS NULL OR servings BETWEEN 1 AND 20),
    ADD CONSTRAINT recipes_ice_check CHECK (ice_g IS NULL OR (ice_g > 0 AND ice_g <= 5000)),
    ADD CONSTRAINT recipes_drink_type_check CHECK (drink_type IS NULL OR drink_type IN
        ('espresso', 'ristretto', 'lungo', 'americano', 'cortado', 'flat_white', 'cappuccino', 'latte',
         'macchiato', 'mocha', 'other')),
    ADD CONSTRAINT recipes_milk_check CHECK (milk_g IS NULL OR (milk_g > 0 AND milk_g <= 2000)),
    ADD CONSTRAINT recipes_brewer_detail_length CHECK (brewer_detail IS NULL OR char_length(brewer_detail) <= 80);
COMMENT ON COLUMN recipes.ice_g IS 'Ice in the carafe for iced (Japanese-style) brews; part of the drink, not of the ratio.';
COMMENT ON COLUMN recipes.brewer_detail IS 'The exact brewer, e.g. "V60 02 ceramic".';

-- A bag's purchase details and photo. photo_url becomes an uploaded image, like avatars.
ALTER TABLE coffee_beans
    DROP COLUMN photo_url,
    ADD COLUMN photo_media_id uuid REFERENCES media (id) ON DELETE SET NULL,
    ADD COLUMN purchase_date  date,
    ADD COLUMN opened_date    date,
    ADD COLUMN price          numeric(8,2),
    ADD COLUMN currency       char(3),
    ADD COLUMN lot            text,
    ADD COLUMN is_favorite    boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT coffee_beans_photo_media_key UNIQUE (photo_media_id),
    ADD CONSTRAINT coffee_beans_opened_after_purchase CHECK (
        opened_date IS NULL OR purchase_date IS NULL OR opened_date >= purchase_date),
    ADD CONSTRAINT coffee_beans_price_check CHECK (price IS NULL OR (price >= 0 AND price <= 1000000)),
    ADD CONSTRAINT coffee_beans_currency_format CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
    ADD CONSTRAINT coffee_beans_price_currency CHECK (price IS NULL OR currency IS NOT NULL),
    ADD CONSTRAINT coffee_beans_lot_length CHECK (lot IS NULL OR char_length(lot) <= 60);
COMMENT ON COLUMN coffee_beans.currency IS 'ISO 4217 code of price.';
CREATE INDEX coffee_beans_favorite_idx ON coffee_beans (owner_id) WHERE is_favorite;

-- Single place that knows every use of an uploaded image. Each image has exactly one use.
CREATE FUNCTION media_in_use(p_media uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
    SELECT EXISTS (SELECT 1 FROM post_media WHERE media_id = p_media)
        OR EXISTS (SELECT 1 FROM users WHERE avatar_media_id = p_media)
        OR EXISTS (SELECT 1 FROM brew_logs WHERE photo_media_id = p_media)
        OR EXISTS (SELECT 1 FROM coffee_beans WHERE photo_media_id = p_media)
        OR EXISTS (SELECT 1 FROM recipes WHERE cover_media_id = p_media)
$$;
COMMENT ON FUNCTION media_in_use(uuid) IS
    'Whether an image is a post photo, an avatar, a brew photo, a bean photo or a recipe cover.';

-- migrate:down

DROP FUNCTION media_in_use(uuid);

DROP INDEX coffee_beans_favorite_idx;
ALTER TABLE coffee_beans
    DROP COLUMN is_favorite,
    DROP COLUMN lot,
    DROP COLUMN currency,
    DROP COLUMN price,
    DROP COLUMN opened_date,
    DROP COLUMN purchase_date,
    DROP COLUMN photo_media_id,
    ADD COLUMN photo_url text;

ALTER TABLE recipes
    DROP COLUMN brewer_detail,
    DROP COLUMN milk_g,
    DROP COLUMN drink_type,
    DROP COLUMN ice_g,
    DROP COLUMN servings,
    DROP COLUMN cover_media_id,
    ADD COLUMN tds_percent numeric(4,2),
    ADD COLUMN rating smallint,
    ADD COLUMN extraction_yield_percent numeric(5,2) GENERATED ALWAYS AS
        (round(yield_g * tds_percent / nullif(dose_g, 0), 2)) STORED,
    ADD CONSTRAINT recipes_tds_check CHECK (tds_percent IS NULL OR (tds_percent > 0 AND tds_percent <= 25)),
    ADD CONSTRAINT recipes_rating_check CHECK (rating IS NULL OR rating BETWEEN 1 AND 5);
COMMENT ON COLUMN recipes.extraction_yield_percent IS 'EY% = beverage weight x TDS% / dose.';
