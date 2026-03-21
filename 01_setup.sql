-- ============================================================
-- ЕКСПЕРИМЕНТ: Сповільнення запису через індекси в PostgreSQL
-- Файл: 01_setup.sql — Створення таблиць та індексів
-- ============================================================

DROP TABLE IF EXISTS test_no_index    CASCADE;
DROP TABLE IF EXISTS test_btree       CASCADE;
DROP TABLE IF EXISTS test_hash        CASCADE;
DROP TABLE IF EXISTS test_brin        CASCADE;
DROP TABLE IF EXISTS test_gin         CASCADE;
DROP TABLE IF EXISTS test_partial     CASCADE;
DROP TABLE IF EXISTS test_multi_index CASCADE;

-- -----------------------------------------------
-- 1. Без індексів (контрольна група)
-- -----------------------------------------------
CREATE TABLE test_no_index (
    id         BIGSERIAL   PRIMARY KEY,
    username   TEXT        NOT NULL,
    email      TEXT        NOT NULL,
    score      INTEGER     NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tags       TEXT[]      NOT NULL DEFAULT '{}',
    payload    JSONB       NOT NULL DEFAULT '{}'
);

-- -----------------------------------------------
-- 2. B-tree — найпоширеніший тип
-- -----------------------------------------------
CREATE TABLE test_btree (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_btree_username ON test_btree USING BTREE (username);
CREATE INDEX idx_btree_email    ON test_btree USING BTREE (email);
CREATE INDEX idx_btree_score    ON test_btree USING BTREE (score);

-- -----------------------------------------------
-- 3. Hash — тільки для = порівнянь
-- -----------------------------------------------
CREATE TABLE test_hash (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_hash_username ON test_hash USING HASH (username);
CREATE INDEX idx_hash_email    ON test_hash USING HASH (email);

-- -----------------------------------------------
-- 4. BRIN — для великих таблиць з фізично
--    впорядкованими (корельованими) даними
-- -----------------------------------------------
CREATE TABLE test_brin (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_brin_created_at ON test_brin USING BRIN (created_at);
CREATE INDEX idx_brin_score      ON test_brin USING BRIN (score);

-- -----------------------------------------------
-- 5. GIN — для масивів (TEXT[]) та JSONB
-- -----------------------------------------------
CREATE TABLE test_gin (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_gin_tags    ON test_gin USING GIN (tags);
CREATE INDEX idx_gin_payload ON test_gin USING GIN (payload);

-- -----------------------------------------------
-- 6. Partial — індекс лише по підмножині рядків
-- -----------------------------------------------
CREATE TABLE test_partial (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_partial_high_score ON test_partial USING BTREE (score)
    WHERE score > 500;
CREATE INDEX idx_partial_gmail ON test_partial USING BTREE (email)
    WHERE email LIKE '%@gmail.com';

-- -----------------------------------------------
-- 7. Multi — всі типи разом (найгірший випадок)
-- -----------------------------------------------
CREATE TABLE test_multi_index (LIKE test_no_index INCLUDING DEFAULTS);
CREATE INDEX idx_multi_username   ON test_multi_index USING BTREE (username);
CREATE INDEX idx_multi_email      ON test_multi_index USING BTREE (email);
CREATE INDEX idx_multi_score      ON test_multi_index USING BTREE (score);
CREATE INDEX idx_multi_created_at ON test_multi_index USING BTREE (created_at);
CREATE INDEX idx_multi_tags       ON test_multi_index USING GIN  (tags);
CREATE INDEX idx_multi_payload    ON test_multi_index USING GIN  (payload);
CREATE INDEX idx_multi_hash_email ON test_multi_index USING HASH (email);

SELECT 'OK: таблиці та індекси створено' AS status;
