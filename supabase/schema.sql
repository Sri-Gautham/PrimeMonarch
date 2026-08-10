-- PrimeMonarch Supabase Schema
-- Run these statements in order in the Supabase SQL editor (Dashboard → SQL Editor).
-- All tables use RLS; users can only read/write their own rows.

-- ============================================================
-- user_profiles
-- id = Supabase auth.users UUID (natural primary key)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_profiles (
    id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name            TEXT,
    date_of_birth           DATE,
    biological_sex          TEXT,
    height_cm               DOUBLE PRECISION,
    current_weight_kg       DOUBLE PRECISION,
    target_weight_kg        DOUBLE PRECISION,
    preferred_weight_unit   TEXT NOT NULL DEFAULT 'kg',
    preferred_distance_unit TEXT NOT NULL DEFAULT 'km',
    onboarding_completed    BOOLEAN NOT NULL DEFAULT false,
    onboarding_step         INTEGER NOT NULL DEFAULT 0,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_profiles: select own"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "user_profiles: insert own"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "user_profiles: update own"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- ============================================================
-- goal_profiles
-- One row per user (UNIQUE on user_id).
-- Upsert with onConflict: "user_id" from the Swift client.
-- ============================================================

CREATE TABLE IF NOT EXISTS goal_profiles (
    id                                 UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                            UUID    NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    goals                              TEXT[]  NOT NULL DEFAULT '{}',
    primary_goal                       TEXT,
    activity_level                     TEXT,
    available_equipment                TEXT[]  NOT NULL DEFAULT '{}',
    workout_days_per_week              INTEGER NOT NULL DEFAULT 3,
    preferred_workout_duration_minutes INTEGER NOT NULL DEFAULT 45,
    updated_at                         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

ALTER TABLE goal_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "goal_profiles: all own"
    ON goal_profiles FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- user_preferences
-- One row per user (UNIQUE on user_id).
-- Upsert with onConflict: "user_id" from the Swift client.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_preferences (
    id                   UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID      NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    dietary_style_values TEXT[]    NOT NULL DEFAULT '{}',
    meals_per_day        INTEGER   NOT NULL DEFAULT 3,
    wake_hour            INTEGER   NOT NULL DEFAULT 7,
    wake_minute          INTEGER   NOT NULL DEFAULT 0,
    sleep_hour           INTEGER   NOT NULL DEFAULT 23,
    sleep_minute         INTEGER   NOT NULL DEFAULT 0,
    workout_time_hour    INTEGER   NOT NULL DEFAULT 8,
    workout_time_minute  INTEGER   NOT NULL DEFAULT 0,
    workdays             INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5}',
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_preferences: all own"
    ON user_preferences FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- Utility: auto-update updated_at on every UPDATE
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER goal_profiles_updated_at
    BEFORE UPDATE ON goal_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
