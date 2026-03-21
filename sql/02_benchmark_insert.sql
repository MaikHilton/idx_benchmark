-- ============================================================
-- ЕКСПЕРИМЕНТ: Сповільнення запису через індекси в PostgreSQL
-- Файл: 02_benchmark_insert.sql
-- ============================================================
-- Використовує ЧИСТИЙ generate_series без допоміжних функцій.
-- Дані генеруються прямо у VALUES через вирази PostgreSQL.
-- ============================================================

-- Таблиця для збереження результатів
DROP TABLE IF EXISTS bench_results;
CREATE TABLE bench_results (
    id           SERIAL      PRIMARY KEY,
    table_name   TEXT        NOT NULL,
    index_type   TEXT        NOT NULL,
    index_count  SMALLINT    NOT NULL,
    rows_count   INTEGER     NOT NULL,
    duration_ms  NUMERIC(10,2) NOT NULL,
    rows_per_sec INTEGER     NOT NULL,
    operation    TEXT        NOT NULL DEFAULT 'INSERT',
    measured_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Допоміжна процедура: замірює INSERT і зберігає результат
-- ============================================================
CREATE OR REPLACE PROCEDURE run_insert_bench(
    p_table      TEXT,
    p_index_type TEXT,
    p_idx_count  SMALLINT,
    p_rows       INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_start  TIMESTAMPTZ;
    v_end    TIMESTAMPTZ;
    v_ms     NUMERIC;
BEGIN
    -- Очистка таблиці перед тестом
    EXECUTE format('TRUNCATE %I RESTART IDENTITY', p_table);

    -- ----------------------------------------------------------
    -- Основний INSERT з generate_series
    -- Дані генеруються виразами прямо в SELECT:
    --   username  — 'user_' + порядковий номер
    --   email     — комбінація md5 + домен з масиву
    --   score     — випадкове ціле 0..999
    --   created_at — поточний момент (монотонно зростає → добре для BRIN)
    --   tags      — масив з 1..5 випадкових тегів
    --   payload   — JSONB об'єкт з двома полями
    -- ----------------------------------------------------------
    v_start := clock_timestamp();

    EXECUTE format($sql$
        INSERT INTO %I (username, email, score, created_at, tags, payload)
        SELECT
            'user_' || i                                            AS username,
            'u' || substr(md5(i::text), 1, 8)
                || '@'
                || (ARRAY['gmail.com','yahoo.com','ukr.net',
                           'outlook.com','meta.ua'])[1 + (i %% 5)] AS email,
            (random() * 999)::int                                   AS score,
            NOW() + (i || ' seconds')::interval                    AS created_at,
            ARRAY(
                SELECT (ARRAY['tech','news','sport','music','art',
                               'food','travel','science','health','finance'])
                       [1 + floor(random()*10)::int]
                FROM generate_series(1, 1 + (i %% 5))
            )                                                       AS tags,
            jsonb_build_object(
                'level',  (i %% 10),
                'active', (i %% 2 = 0)
            )                                                       AS payload
        FROM generate_series(1, %s) AS i
    $sql$, p_table, p_rows);

    v_end := clock_timestamp();
    v_ms  := round(extract(epoch FROM (v_end - v_start)) * 1000, 2);

    INSERT INTO bench_results
        (table_name, index_type, index_count, rows_count, duration_ms, rows_per_sec)
    VALUES
        (p_table, p_index_type, p_idx_count, p_rows,
         v_ms, (p_rows / GREATEST(v_ms / 1000, 0.001))::int);

    RAISE NOTICE '% | % | % рядків | % мс',
        p_table, p_index_type, p_rows, v_ms;
END;
$$;

-- ============================================================
-- ЗАПУСК ТЕСТІВ: 3 розміри × 7 конфігурацій
-- ============================================================

CALL run_insert_bench('test_no_index',    'None',    0::smallint, 100000);
CALL run_insert_bench('test_btree',       'B-tree',  3::smallint, 100000);
CALL run_insert_bench('test_hash',        'Hash',    2::smallint, 100000);
CALL run_insert_bench('test_brin',        'BRIN',    2::smallint, 100000);
CALL run_insert_bench('test_gin',         'GIN',     2::smallint, 100000);
CALL run_insert_bench('test_partial',     'Partial', 2::smallint, 100000);
CALL run_insert_bench('test_multi_index', 'Multi',   7::smallint, 100000);

CALL run_insert_bench('test_no_index',    'None',    0::smallint, 500000);
CALL run_insert_bench('test_btree',       'B-tree',  3::smallint, 500000);
CALL run_insert_bench('test_hash',        'Hash',    2::smallint, 500000);
CALL run_insert_bench('test_brin',        'BRIN',    2::smallint, 500000);
CALL run_insert_bench('test_gin',         'GIN',     2::smallint, 500000);
CALL run_insert_bench('test_partial',     'Partial', 2::smallint, 500000);
CALL run_insert_bench('test_multi_index', 'Multi',   7::smallint, 500000);

CALL run_insert_bench('test_no_index',    'None',    0::smallint, 1000000);
CALL run_insert_bench('test_btree',       'B-tree',  3::smallint, 1000000);
CALL run_insert_bench('test_hash',        'Hash',    2::smallint, 1000000);
CALL run_insert_bench('test_brin',        'BRIN',    2::smallint, 1000000);
CALL run_insert_bench('test_gin',         'GIN',     2::smallint, 1000000);
CALL run_insert_bench('test_partial',     'Partial', 2::smallint, 1000000);
CALL run_insert_bench('test_multi_index', 'Multi',   7::smallint, 1000000);

-- ============================================================
-- ПІДСУМКОВА ТАБЛИЦЯ
-- ============================================================
SELECT
    index_type                    AS "Тип індексу",
    index_count                   AS "Індексів",
    rows_count                    AS "Рядків",
    duration_ms                   AS "Час, мс",
    rows_per_sec                  AS "Рядків/сек",
    round(
        100.0 * (duration_ms - min(duration_ms) OVER (PARTITION BY rows_count))
              / NULLIF(min(duration_ms) OVER (PARTITION BY rows_count), 0),
        1
    )                             AS "Уповільнення, %"
FROM bench_results
WHERE operation = 'INSERT'
ORDER BY rows_count, duration_ms;