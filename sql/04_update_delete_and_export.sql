-- ===========================================================
-- ЕКСПЕРИМЕНТ: Сповільнення запису через індекси в PostgreSQL
-- Файл: 04_update_delete_and_export.sql
-- ===========================================================

-- UPDATE benchmark
CREATE OR REPLACE PROCEDURE run_update_bench(
    p_table      TEXT,
    p_index_type TEXT,
    p_idx_count  SMALLINT,
    p_rows       INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_start TIMESTAMPTZ;
    v_end   TIMESTAMPTZ;
    v_ms    NUMERIC;
    v_max   INTEGER;
    v_sql   TEXT;
BEGIN
    EXECUTE format('SELECT count(*) FROM %I', p_table) INTO v_max;

    IF v_max < p_rows THEN
        RAISE WARNING '% - zamalo ryadkiv (ye %, potribno %)', p_table, v_max, p_rows;
        RETURN;
    END IF;

    v_start := clock_timestamp();

    v_sql := format(
        'UPDATE %I SET score = (random() * 999)::int, payload = jsonb_build_object(''updated'', true) WHERE id IN (SELECT i FROM generate_series(1, %s) AS i)',
        p_table, p_rows
    );
    EXECUTE v_sql;

    v_end := clock_timestamp();
    v_ms  := round(extract(epoch FROM (v_end - v_start)) * 1000, 2);

    INSERT INTO bench_results
        (table_name, index_type, index_count, rows_count, duration_ms, rows_per_sec, operation)
    VALUES
        (p_table, p_index_type, p_idx_count, p_rows,
         v_ms, (p_rows / GREATEST(v_ms/1000, 0.001))::int, 'UPDATE');

    RAISE NOTICE 'UPDATE % | % rows | % ms', p_table, p_rows, v_ms;
END;
$$;

-- DELETE benchmark
CREATE OR REPLACE PROCEDURE run_delete_bench(
    p_table      TEXT,
    p_index_type TEXT,
    p_idx_count  SMALLINT,
    p_rows       INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_start TIMESTAMPTZ;
    v_end   TIMESTAMPTZ;
    v_ms    NUMERIC;
    v_sql   TEXT;
BEGIN
    v_start := clock_timestamp();

    v_sql := format(
        'DELETE FROM %I WHERE id IN (SELECT i FROM generate_series(1, %s) AS i)',
        p_table, p_rows
    );
    EXECUTE v_sql;

    v_end := clock_timestamp();
    v_ms  := round(extract(epoch FROM (v_end - v_start)) * 1000, 2);

    INSERT INTO bench_results
        (table_name, index_type, index_count, rows_count, duration_ms, rows_per_sec, operation)
    VALUES
        (p_table, p_index_type, p_idx_count, p_rows,
         v_ms, (p_rows / GREATEST(v_ms/1000, 0.001))::int, 'DELETE');

    RAISE NOTICE 'DELETE % | % rows | % ms', p_table, p_rows, v_ms;
END;
$$;

-- ============================================================
-- ЗАПУСК UPDATE (50 000 рядків)
-- ============================================================
CALL run_update_bench('test_no_index',    'None',    0::smallint, 50000);
CALL run_update_bench('test_btree',       'B-tree',  3::smallint, 50000);
CALL run_update_bench('test_hash',        'Hash',    2::smallint, 50000);
CALL run_update_bench('test_brin',        'BRIN',    2::smallint, 50000);
CALL run_update_bench('test_gin',         'GIN',     2::smallint, 50000);
CALL run_update_bench('test_partial',     'Partial', 2::smallint, 50000);
CALL run_update_bench('test_multi_index', 'Multi',   7::smallint, 50000);

-- ============================================================
-- ЗАПУСК DELETE (10 000 рядків)
-- ============================================================
CALL run_delete_bench('test_no_index',    'None',    0::smallint, 10000);
CALL run_delete_bench('test_btree',       'B-tree',  3::smallint, 10000);
CALL run_delete_bench('test_hash',        'Hash',    2::smallint, 10000);
CALL run_delete_bench('test_brin',        'BRIN',    2::smallint, 10000);
CALL run_delete_bench('test_gin',         'GIN',     2::smallint, 10000);
CALL run_delete_bench('test_partial',     'Partial', 2::smallint, 10000);
CALL run_delete_bench('test_multi_index', 'Multi',   7::smallint, 10000);

-- ============================================================
-- ФІНАЛЬНИЙ ПІДСУМОК
-- ============================================================
SELECT
    operation    AS "Операція",
    index_type   AS "Тип індексу",
    index_count  AS "Індексів",
    rows_count   AS "Рядків",
    duration_ms  AS "Час, мс",
    rows_per_sec AS "Рядків/сек"
FROM bench_results
ORDER BY operation, rows_count, duration_ms;
