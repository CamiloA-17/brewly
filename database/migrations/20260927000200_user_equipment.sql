-- migrate:up

-- The gear each member owns: grinders, brewers, kettles, scales and espresso machines.
-- Shown on the member's profile; the default grinder and its usual setting per brew method
-- pre-fill recipe forms.
CREATE TABLE user_equipment (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind          text        NOT NULL,
    grinder_slug  text        REFERENCES grinders (slug) ON UPDATE CASCADE,
    brand         text,
    model         text,
    nickname      text,
    notes         text,
    is_default    boolean     NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    -- Target of composite foreign keys that guarantee ownership (brew logs).
    CONSTRAINT user_equipment_id_owner_key UNIQUE (id, owner_id),
    CONSTRAINT user_equipment_kind_check CHECK (kind IN
        ('grinder', 'brewer', 'kettle', 'scale', 'espresso_machine', 'other')),
    CONSTRAINT user_equipment_grinder_kind CHECK (grinder_slug IS NULL OR kind = 'grinder'),
    -- Catalog grinders are named by the catalog; anything else needs a brand, model or nickname.
    CONSTRAINT user_equipment_named CHECK (num_nonnulls(grinder_slug, brand, model, nickname) > 0),
    CONSTRAINT user_equipment_brand_length CHECK (brand IS NULL OR char_length(brand) BETWEEN 1 AND 60),
    CONSTRAINT user_equipment_model_length CHECK (model IS NULL OR char_length(model) BETWEEN 1 AND 60),
    CONSTRAINT user_equipment_nickname_length CHECK (nickname IS NULL OR char_length(nickname) BETWEEN 1 AND 60),
    CONSTRAINT user_equipment_notes_length CHECK (notes IS NULL OR char_length(notes) <= 500)
);
COMMENT ON TABLE user_equipment IS 'Gear owned by a member. Public on their profile.';
COMMENT ON COLUMN user_equipment.grinder_slug IS 'Catalog grinder; brand and model are free text for anything else.';
COMMENT ON COLUMN user_equipment.is_default IS 'The item used by default for its kind (at most one per kind).';

CREATE INDEX user_equipment_owner_idx ON user_equipment (owner_id, kind, created_at);
CREATE INDEX user_equipment_grinder_idx ON user_equipment (grinder_slug);
CREATE UNIQUE INDEX user_equipment_one_default_idx ON user_equipment (owner_id, kind) WHERE is_default;

CREATE TRIGGER user_equipment_set_updated_at
    BEFORE UPDATE ON user_equipment
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- A grinder's usual setting for each brew method, e.g. "24 clicks" for V60.
CREATE TABLE equipment_grind_settings (
    equipment_id   uuid NOT NULL REFERENCES user_equipment (id) ON DELETE CASCADE,
    method_slug    text NOT NULL REFERENCES brew_methods (slug) ON UPDATE CASCADE,
    grind_setting  text NOT NULL,
    PRIMARY KEY (equipment_id, method_slug),
    -- Same limit as recipes.grind_setting, which it pre-fills.
    CONSTRAINT equipment_grind_settings_length CHECK (char_length(grind_setting) BETWEEN 1 AND 40)
);
COMMENT ON TABLE equipment_grind_settings IS 'Usual grind setting of a grinder per brew method (grinders only, checked by the API).';
CREATE INDEX equipment_grind_settings_method_idx ON equipment_grind_settings (method_slug);

-- migrate:down

DROP TABLE equipment_grind_settings;
DROP TABLE user_equipment;
