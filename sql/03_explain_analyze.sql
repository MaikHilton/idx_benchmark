-- ============================================================
-- ЕКСПЕРИМЕНТ: Сповільнення запису через індекси в PostgreSQL
-- Файл: 03_explain_analyze.sql
-- ============================================================
-- EXPLAIN ANALYZE для кожного типу індексу.
-- JSON-вивід → скопіювати у explain.dalibo.com
-- ============================================================

-- ============================================================
-- ЧАСТИНА A: EXPLAIN для INSERT (окремий рядок)
-- Показує вартість одного INSERT із планувальника
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
INSERT INTO test_no_index (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@gmail.com',
    (random() * 999)::int,
    ARRAY['tech','news'],
    jsonb_build_object('level', i % 10)
FROM generate_series(1, 10000) AS i;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
INSERT INTO test_btree (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@gmail.com',
    (random() * 999)::int,
    ARRAY['tech','news'],
    jsonb_build_object('level', i % 10)
FROM generate_series(1, 10000) AS i;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
INSERT INTO test_gin (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@gmail.com',
    (random() * 999)::int,
    ARRAY['tech','news'],
    jsonb_build_object('level', i % 10)
FROM generate_series(1, 10000) AS i;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
INSERT INTO test_multi_index (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@gmail.com',
    (random() * 999)::int,
    ARRAY['tech','news'],
    jsonb_build_object('level', i % 10)
FROM generate_series(1, 10000) AS i;

-- ============================================================
-- ЧАСТИНА B: EXPLAIN FORMAT JSON
-- Для вставки в explain.dalibo.com
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
INSERT INTO test_no_index (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@yahoo.com',
    (random() * 999)::int,
    ARRAY['sport'],
    jsonb_build_object('active', true)
FROM generate_series(1, 5000) AS i;

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
INSERT INTO test_multi_index (username, email, score, tags, payload)
SELECT
    'user_' || i,
    'u' || substr(md5(i::text),1,8) || '@yahoo.com',
    (random() * 999)::int,
    ARRAY['sport'],
    jsonb_build_object('active', true)
FROM generate_series(1, 5000) AS i;

-- ============================================================
-- ЧАСТИНА C: Розмір індексів після заповнення
-- ============================================================
SELECT
    relname                                      AS "Об'єкт",
    CASE relkind
        WHEN 'r' THEN 'таблиця'
        WHEN 'i' THEN 'індекс'
    END                                          AS "Тип",
    pg_size_pretty(pg_relation_size(oid))        AS "Розмір",
    pg_size_pretty(pg_total_relation_size(oid))  AS "З індексами"
FROM pg_class
WHERE relname LIKE 'test_%'
  AND relkind IN ('r','i')
ORDER BY relkind DESC, pg_relation_size(oid) DESC;

-- ============================================================
-- ЧАСТИНА D: UPDATE — EXPLAIN ANALYZE
-- Показує вплив індексів на UPDATE
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
UPDATE test_no_index
SET score = (random() * 999)::int
WHERE id IN (
    SELECT id FROM generate_series(1, 1000) AS i
);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
UPDATE test_btree
SET score = (random() * 999)::int
WHERE id IN (
    SELECT id FROM generate_series(1, 1000) AS i
);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
UPDATE test_multi_index
SET score = (random() * 999)::int
WHERE id IN (
    SELECT id FROM generate_series(1, 1000) AS i
);
