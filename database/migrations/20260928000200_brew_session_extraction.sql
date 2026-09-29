-- migrate:up

-- Preserve extraction measurements that used to live on recipe rows.
ALTER TABLE brew_sessions
    ADD COLUMN tds_percent numeric(4,2),
    ADD COLUMN extraction_yield_percent numeric(5,2)
        GENERATED ALWAYS AS (round(yield_g * tds_percent / nullif(dose_g, 0), 2)) STORED,
    ADD CONSTRAINT brew_sessions_tds_check
        CHECK (tds_percent IS NULL OR tds_percent > 0 AND tds_percent <= 25);

UPDATE brew_sessions s SET tds_percent = r.tds_percent
FROM recipes r
WHERE s.recipe_id = r.id AND s.created_at = r.created_at AND s.tds_percent IS NULL;

-- migrate:down

ALTER TABLE brew_sessions
    DROP CONSTRAINT brew_sessions_tds_check,
    DROP COLUMN extraction_yield_percent,
    DROP COLUMN tds_percent;
