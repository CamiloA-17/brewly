-- migrate:up

ALTER TABLE brew_sessions
    ADD CONSTRAINT brew_sessions_water_or_yield CHECK (water_g IS NOT NULL OR yield_g IS NOT NULL);

-- migrate:down

ALTER TABLE brew_sessions DROP CONSTRAINT brew_sessions_water_or_yield;
