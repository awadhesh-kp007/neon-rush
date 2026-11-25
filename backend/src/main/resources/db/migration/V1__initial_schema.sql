-- ============================================================
-- NEON RUSH: CITY ESCAPE — Initial Database Schema
-- Migration: V1__initial_schema.sql
-- Engine: PostgreSQL 17 | Flyway managed
-- Convention: UUID PKs, UTC timestamps, snake_case columns
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ─────────────────────────────────────────────────────────────
-- USERS & AUTH
-- ─────────────────────────────────────────────────────────────

CREATE TABLE users (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(320) NOT NULL,
    username        VARCHAR(32)  NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    email_verified  BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_users_email    UNIQUE (email),
    CONSTRAINT uk_users_username UNIQUE (username)
);

CREATE INDEX idx_users_email_lower ON users (LOWER(email));
CREATE INDEX idx_users_username_trgm ON users USING gin (username gin_trgm_ops);

CREATE TABLE user_sessions (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id          VARCHAR(128) NOT NULL,
    device_name        VARCHAR(255),
    refresh_token_hash VARCHAR(255) NOT NULL,
    expires_at         TIMESTAMPTZ  NOT NULL,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_used_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_revoked         BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uk_user_sessions_token UNIQUE (refresh_token_hash)
);

CREATE INDEX idx_user_sessions_user   ON user_sessions (user_id);
CREATE INDEX idx_user_sessions_expiry ON user_sessions (expires_at) WHERE NOT is_revoked;

-- ─────────────────────────────────────────────────────────────
-- PLAYER PROFILE & PROGRESSION
-- ─────────────────────────────────────────────────────────────

CREATE TABLE player_profiles (
    player_id    UUID         PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(32)  NOT NULL,
    avatar_url   VARCHAR(512),
    country_code CHAR(2),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE player_xp (
    player_id  UUID    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    xp         BIGINT  NOT NULL DEFAULT 0 CHECK (xp >= 0),
    level      INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE player_statistics (
    player_id          UUID    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_runs         INTEGER NOT NULL DEFAULT 0,
    best_score         BIGINT  NOT NULL DEFAULT 0,
    best_distance_m    FLOAT   NOT NULL DEFAULT 0,
    total_coins_earned BIGINT  NOT NULL DEFAULT 0,
    play_time_seconds  BIGINT  NOT NULL DEFAULT 0,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- ECONOMY (WALLET)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE player_wallet (
    player_id  UUID    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    coins      BIGINT  NOT NULL DEFAULT 0 CHECK (coins >= 0),
    gems       BIGINT  NOT NULL DEFAULT 0 CHECK (gems >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version    INTEGER NOT NULL DEFAULT 0  -- Optimistic locking
);

CREATE TABLE wallet_transactions (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID         NOT NULL REFERENCES users(id),
    currency_type   VARCHAR(10)  NOT NULL,  -- COINS | GEMS
    amount          BIGINT       NOT NULL,  -- Positive = credit, negative = debit
    reason          VARCHAR(100) NOT NULL,
    reference_id    VARCHAR(255),           -- game_run_id, mission_id, purchase_id
    idempotency_key UUID         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_wallet_tx_idempotency UNIQUE (idempotency_key)
);

CREATE INDEX idx_wallet_tx_player ON wallet_transactions (player_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────
-- GAME SESSIONS & RUNS
-- ─────────────────────────────────────────────────────────────

CREATE TABLE game_sessions (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id         UUID        NOT NULL REFERENCES users(id),
    session_hmac_hash VARCHAR(255) NOT NULL,
    seed              BIGINT      NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ NOT NULL,
    completed_at      TIMESTAMPTZ
);

CREATE INDEX idx_game_sessions_player ON game_sessions (player_id);
CREATE INDEX idx_game_sessions_active  ON game_sessions (status) WHERE status = 'ACTIVE';

CREATE TABLE game_runs (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id        UUID        NOT NULL UNIQUE REFERENCES game_sessions(id),
    player_id         UUID        NOT NULL REFERENCES users(id),
    score             BIGINT      NOT NULL DEFAULT 0,
    distance_m        FLOAT       NOT NULL DEFAULT 0,
    coins_collected   INTEGER     NOT NULL DEFAULT 0,
    duration_ms       BIGINT      NOT NULL DEFAULT 0,
    validation_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    validation_notes  TEXT,
    idempotency_key   UUID        NOT NULL,
    completed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_game_runs_idempotency UNIQUE (idempotency_key)
);

CREATE INDEX idx_game_runs_player     ON game_runs (player_id);
CREATE INDEX idx_game_runs_score      ON game_runs (score DESC);
CREATE INDEX idx_game_runs_validation ON game_runs (validation_status) WHERE validation_status = 'PENDING';

-- ─────────────────────────────────────────────────────────────
-- CHARACTERS & INVENTORY
-- ─────────────────────────────────────────────────────────────

CREATE TABLE characters (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(50)  NOT NULL UNIQUE,
    description      TEXT,
    unlock_cost_type VARCHAR(10)  NOT NULL DEFAULT 'COINS',
    unlock_cost      INTEGER      NOT NULL DEFAULT 0,
    rarity           VARCHAR(20)  NOT NULL DEFAULT 'COMMON',
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order       INTEGER      NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO characters (id, name, description, unlock_cost_type, unlock_cost, rarity, sort_order)
VALUES (gen_random_uuid(), 'ZARA', 'Street tech prodigy — the original escapee.', 'FREE', 0, 'COMMON', 0);

CREATE TABLE player_characters (
    player_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    character_id UUID        NOT NULL REFERENCES characters(id),
    unlocked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_selected  BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (player_id, character_id)
);

CREATE TABLE outfits (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    character_id     UUID         NOT NULL REFERENCES characters(id),
    name             VARCHAR(50)  NOT NULL,
    unlock_cost_type VARCHAR(10)  NOT NULL DEFAULT 'COINS',
    unlock_cost      INTEGER      NOT NULL DEFAULT 0,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE player_outfits (
    player_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id   UUID        NOT NULL REFERENCES outfits(id),
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (player_id, outfit_id)
);

-- ─────────────────────────────────────────────────────────────
-- MISSIONS
-- ─────────────────────────────────────────────────────────────

CREATE TABLE missions (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    type           VARCHAR(20)  NOT NULL,
    title          VARCHAR(100) NOT NULL,
    description    TEXT         NOT NULL,
    target_metric  VARCHAR(50)  NOT NULL,
    target_value   INTEGER      NOT NULL,
    reward_type    VARCHAR(10)  NOT NULL,
    reward_value   INTEGER      NOT NULL,
    active_from    TIMESTAMPTZ,
    active_to      TIMESTAMPTZ,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE player_missions (
    player_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mission_id   UUID        NOT NULL REFERENCES missions(id),
    progress     INTEGER     NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ,
    claimed_at   TIMESTAMPTZ,
    PRIMARY KEY (player_id, mission_id)
);

-- ─────────────────────────────────────────────────────────────
-- LEADERBOARDS
-- ─────────────────────────────────────────────────────────────

CREATE TABLE leaderboard_entries (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id   UUID         NOT NULL REFERENCES users(id),
    period_type VARCHAR(10)  NOT NULL,
    period_key  VARCHAR(20)  NOT NULL,
    score       BIGINT       NOT NULL,
    rank        INTEGER,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_leaderboard_player_period UNIQUE (player_id, period_type, period_key)
);

CREATE INDEX idx_leaderboard_score ON leaderboard_entries (period_type, period_key, score DESC);

-- ─────────────────────────────────────────────────────────────
-- PURCHASES
-- ─────────────────────────────────────────────────────────────

CREATE TABLE purchases (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id       UUID         NOT NULL REFERENCES users(id),
    store           VARCHAR(10)  NOT NULL,
    product_id      VARCHAR(255) NOT NULL,
    transaction_id  VARCHAR(255) NOT NULL,
    order_id        VARCHAR(255),
    receipt_hash    VARCHAR(255) NOT NULL,
    amount_usd      NUMERIC(10,2),
    currency_code   CHAR(3),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    validated_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_purchases_receipt UNIQUE (receipt_hash)
);

CREATE INDEX idx_purchases_player ON purchases (player_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────
-- ADMIN
-- ─────────────────────────────────────────────────────────────

CREATE TABLE admin_users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(30)  NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE TABLE audit_logs (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id    UUID         REFERENCES admin_users(id),
    action      VARCHAR(100) NOT NULL,
    target_type VARCHAR(50),
    target_id   VARCHAR(255),
    payload     JSONB,
    ip_address  INET,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin  ON audit_logs (admin_id, created_at DESC);
CREATE INDEX idx_audit_logs_target ON audit_logs (target_type, target_id);
