# Сповільнення запису через індекси в PostgreSQL

Дослідницький проєкт для конференції **IMA 2026**  
Сумський державний університет, гр. ІН-31/1

---

## Мета

Виміряти та порівняти вплив різних типів індексів PostgreSQL на швидкість операцій запису:
**INSERT** — на обсягах 100 000, 500 000 та 1 000 000 рядків.  
Кожен замір повторювався **5 разів**, у таблицях наведено середні значення.

---

## Структура репозиторію

```
├── sql/
│   ├── 01_setup.sql                     # Створення таблиць та індексів
│   ├── 02_benchmark_insert.sql          # Вимірювання INSERT
│   ├── 03_explain_analyze.sql           # EXPLAIN ANALYZE планів запитів
│   └── 04_update_delete_and_export.sql  # Вимірювання UPDATE та DELETE
├── data/
│   ├── results_run_1.csv                # Спроба 1 (14:18)
│   ├── results_run_2.csv                # Спроба 2 (14:27)
│   ├── results_run_3.csv                # Спроба 3 (14:34)
│   ├── results_run_4.csv                # Спроба 4 (14:41)
│   └── results_run_5.csv                # Спроба 5 (14:48)
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
| Кількість спроб | 5 (середнє арифметичне) |

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

## Результати INSERT — середнє по 5 спробах

### 100 000 рядків

| Тип індексу | Індексів | Час, мс | Рядків/сек | Уповільнення |
|---|---|---|---|---|
| BRIN | 2 | 680,7 | 147 122 | еталон |
| None | 0 | 706,0 | 144 854 | +3,8% |
| Partial | 2 | 820,3 | 122 713 | +20,5% |
| Hash | 2 | 947,5 | 105 760 | +39,2% |
| GIN | 2 | 1 332,2 | 75 473 | +95,7% |
| B-tree | 3 | 1 607,7 | 62 849 | +136,2% |
| Multi | 7 | 2 651,7 | 37 890 | +289,5% |

### 500 000 рядків

| Тип індексу | Індексів | Час, мс | Рядків/сек | Уповільнення |
|---|---|---|---|---|
| BRIN | 2 | 3 078,1 | 163 064 | еталон |
| Partial | 2 | 4 252,8 | 117 712 | +38,2% |
| None | 0 | 4 349,4 | 117 526 | +41,3% |
| Hash | 2 | 5 381,9 | 93 265 | +74,8% |
| GIN | 2 | 6 560,1 | 76 653 | +113,1% |
| B-tree | 3 | 8 953,0 | 56 115 | +190,9% |
| Multi | 7 | 13 786,6 | 36 315 | +347,9% |

### 1 000 000 рядків

| Тип індексу | Індексів | Час, мс | Рядків/сек | Уповільнення |
|---|---|---|---|---|
| BRIN | 2 | 6 591,4 | 153 590 | еталон |
| None | 0 | 7 269,3 | 138 312 | +10,3% |
| Partial | 2 | 8 749,1 | 114 744 | +32,7% |
| Hash | 2 | 9 562,6 | 104 903 | +45,1% |
| GIN | 2 | 13 187,1 | 75 908 | +100,1% |
| B-tree | 3 | 18 968,4 | 52 775 | +187,8% |
| Multi | 7 | 27 874,8 | 35 891 | +323,0% |

---

## Головні висновки

**INSERT:**
- **BRIN** — найшвидший при INSERT на всіх обсягах даних. При 1М рядків: **6 591 мс** (153 590 рядків/сек).
- **Multi (7 індексів)** — найповільніший: **27 875 мс** — у **4,2 рази повільніше** за BRIN.
- **None (без індексів)** — при малих обсягах (100К) повільніший за BRIN через відсутність структур, при великих (500К–1М) BRIN випереджає None завдяки мінімальним накладним витратам на обслуговування.
- **B-tree** з 3 індексами уповільнює INSERT на ~190% порівняно з BRIN на 1М рядків.
- Залежність лінійна: кожен додатковий індекс збільшує час INSERT пропорційно.

---

## Джерела

1. PostgreSQL Documentation: Index Types — https://www.postgresql.org/docs/current/indexes-types.html
2. PostgreSQL Documentation: EXPLAIN — https://www.postgresql.org/docs/current/sql-explain.html
3. Use The Index, Luke — https://use-the-index-luke.com/
