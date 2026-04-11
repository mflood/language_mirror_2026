-- Bootstrap: track which migrations have been applied
CREATE TABLE IF NOT EXISTS schema_version (
    id            SERIAL PRIMARY KEY,
    migration_name TEXT UNIQUE NOT NULL,
    applied_at    TIMESTAMPTZ DEFAULT now()
);
