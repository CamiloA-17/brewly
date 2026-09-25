-- migrate:up

-- Global reference catalogs shared by every user. Slugs are stable primary keys
-- (identical across environments); names are canonical English and clients localize them.

CREATE TABLE countries (
    code  char(2) PRIMARY KEY,
    name  text    NOT NULL,
    CONSTRAINT countries_code_format CHECK (code ~ '^[A-Z]{2}$'),
    CONSTRAINT countries_name_key UNIQUE (name)
);
COMMENT ON TABLE countries IS 'Coffee-producing countries (ISO 3166-1 alpha-2).';

CREATE TABLE varietals (
    slug     text PRIMARY KEY,
    name     text NOT NULL,
    species  text NOT NULL DEFAULT 'arabica',
    CONSTRAINT varietals_slug_format CHECK (slug ~ '^[a-z0-9_]+$'),
    CONSTRAINT varietals_name_key UNIQUE (name),
    CONSTRAINT varietals_species_check CHECK (species IN ('arabica', 'robusta', 'liberica'))
);

CREATE TABLE processing_methods (
    slug         text PRIMARY KEY,
    name         text NOT NULL,
    description  text,
    CONSTRAINT processing_methods_slug_format CHECK (slug ~ '^[a-z0-9_]+$'),
    CONSTRAINT processing_methods_name_key UNIQUE (name)
);

CREATE TABLE brew_methods (
    slug                  text         PRIMARY KEY,
    name                  text         NOT NULL,
    category              text         NOT NULL,
    ratio_basis           text         NOT NULL DEFAULT 'water',
    description           text,
    default_ratio         numeric(4,1),
    default_grind_size    grind_size,
    default_water_temp_c  numeric(4,1),
    sort_order            smallint     NOT NULL DEFAULT 0,
    CONSTRAINT brew_methods_slug_format CHECK (slug ~ '^[a-z0-9_]+$'),
    CONSTRAINT brew_methods_name_key UNIQUE (name),
    CONSTRAINT brew_methods_category_check CHECK (category IN
        ('pour_over', 'immersion', 'pressure', 'espresso', 'cold_brew', 'drip_machine', 'other')),
    CONSTRAINT brew_methods_ratio_basis_check CHECK (ratio_basis IN ('water', 'beverage')),
    CONSTRAINT brew_methods_default_ratio_check CHECK (default_ratio IS NULL OR default_ratio > 0),
    CONSTRAINT brew_methods_default_temp_check CHECK (default_water_temp_c IS NULL OR default_water_temp_c BETWEEN 0 AND 100)
);
COMMENT ON COLUMN brew_methods.ratio_basis IS
    'How the brew ratio is expressed: "water" = brew water / dose (filter), "beverage" = drink weight / dose (espresso).';

CREATE TABLE grinders (
    slug       text PRIMARY KEY,
    brand      text NOT NULL,
    model      text NOT NULL,
    kind       text NOT NULL,
    burr_type  text,
    CONSTRAINT grinders_slug_format CHECK (slug ~ '^[a-z0-9_]+$'),
    CONSTRAINT grinders_brand_model_key UNIQUE (brand, model),
    CONSTRAINT grinders_kind_check CHECK (kind IN ('manual', 'electric')),
    CONSTRAINT grinders_burr_type_check CHECK (burr_type IS NULL OR burr_type IN ('conical', 'flat'))
);

CREATE TABLE flavor_notes (
    slug      text PRIMARY KEY,
    name      text NOT NULL,
    category  text NOT NULL,
    CONSTRAINT flavor_notes_slug_format CHECK (slug ~ '^[a-z0-9_]+$'),
    CONSTRAINT flavor_notes_name_key UNIQUE (name),
    CONSTRAINT flavor_notes_category_check CHECK (category IN
        ('fruity', 'floral', 'sweet', 'nutty_cocoa', 'spices', 'roasted', 'sour_fermented', 'green_vegetative', 'other'))
);
COMMENT ON TABLE flavor_notes IS 'Tasting notes grouped by the top level of the SCA Coffee Taster''s Flavor Wheel.';

-- migrate:down

DROP TABLE flavor_notes;
DROP TABLE grinders;
DROP TABLE brew_methods;
DROP TABLE processing_methods;
DROP TABLE varietals;
DROP TABLE countries;
