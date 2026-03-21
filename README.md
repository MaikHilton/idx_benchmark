# Сповільнення запису через індекси в PostgreSQL

Дослідницький проєкт для конференції **IMA 2025**  
Сумський державний університет, гр. ІН-31/1

---

## Мета

Виміряти та порівняти вплив різних типів індексів PostgreSQL на швидкість операцій запису:
**INSERT**, **UPDATE**, **DELETE** — на обсягах 100 000, 500 000 та 1 000 000 рядків.

---

## Структура репозиторію

```
├── sql/
│   ├── 01_setup.sql                     # Створення таблиць та індексів
│   ├── 02_benchmark_insert.sql          # Вимірювання INSERT
│   ├── 03_explain_analyze.sql           # EXPLAIN ANALYZE планів запитів
│   └── 04_update_delete_and_export.sql  # Вимірювання UPDATE та DELETE
├── data/
│   └── results.csv                      # Сирі результати експерименту
└── README.md
```

---

## Середовище експерименту

| Параметр | Значення |
|---|---|
| СУБД | PostgreSQL 18.3 |
| ОС | Windows 11 |
| RAM | 16 GB DDR5 (одноканал) |
| Інструмент | DBeaver 26 |

Перевірити налаштування PostgreSQL:
```sql
SELECT version();
SHOW shared_buffers;
SHOW work_mem;
SHOW max_wal_size;
```

---

## Як запустити

### 1. Створити базу даних

```sql
CREATE DATABASE idx_benchmark;
```

### 2. Запустити скрипти по порядку

Відкрити DBeaver → підключитись до `idx_benchmark` → відкрити кожен файл і виконати:

```
01_setup.sql                     -- створює 7 таблиць з різними індексами
02_benchmark_insert.sql          -- вимірює INSERT (займає 5-10 хвилин)
03_explain_analyze.sql           -- збирає EXPLAIN плани
04_update_delete_and_export.sql  -- вимірює UPDATE і DELETE
```

### 3. Переглянути результати

```sql
SELECT operation, index_type, rows_count, duration_ms, rows_per_sec
FROM bench_results
ORDER BY operation, rows_count, duration_ms;
```

---

## Типи індексів у експерименті

| Таблиця | Тип | К-сть індексів | Поля |
|---|---|---|---|
| `test_no_index` | — | 0 | Контрольна група |
| `test_btree` | B-tree | 3 | username, email, score |
| `test_hash` | Hash | 2 | username, email |
| `test_brin` | BRIN | 2 | created_at, score |
| `test_gin` | GIN | 2 | tags (TEXT[]), payload (JSONB) |
| `test_partial` | Partial B-tree | 2 | score > 500, email LIKE '%@gmail.com' |
| `test_multi_index` | Mix | 7 | всі типи разом |

---

## Результати (INSERT, 1 000 000 рядків)

| Тип індексу | Час, мс | Рядків/сек | Уповільнення |
|---|---|---|---|
| BRIN | 5 358 | 186 639 | еталон |
| None | 6 659 | 150 171 | +24% |
| Partial | 7 120 | 140 442 | +33% |
| Hash | 10 123 | 98 781 | +89% |
| GIN | 11 637 | 85 935 | +117% |
| B-tree | 17 877 | 55 939 | +234% |
| Multi (7 індексів) | 26 143 | 38 251 | +388% |

**Головний висновок:** конфігурація з 7 індексами (Multi) у **4.9 рази повільніша** за BRIN при INSERT на 1М рядків.

---

## Джерела

1. PostgreSQL Documentation: Index Types — https://www.postgresql.org/docs/current/indexes-types.html
2. PostgreSQL Documentation: EXPLAIN — https://www.postgresql.org/docs/current/sql-explain.html
3. Use The Index, Luke — https://use-the-index-luke.com/
