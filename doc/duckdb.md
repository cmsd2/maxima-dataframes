## DuckDB Integration

The `dataframes-duckdb` extension adds file I/O, SQL queries, and DuckDB-accelerated operations to the dataframes package. It requires `libduckdb` (`brew install duckdb` on macOS).

```maxima
load("dataframes-duckdb")$
```

**Type mapping:** DuckDB DOUBLE → ndarray (f64), INTEGER/BIGINT → ndarray (coerced to f64), VARCHAR → string-column, NULL → NaN (numeric) or "" (string).

### Function: df_read_csv (path)

Read a CSV file into a df_table. DuckDB auto-detects column types, delimiters, and encoding.

#### Examples

```maxima
(%i1) T : df_read_csv("/path/to/data.csv")$
(%i2) df_table_shape(T);
(%o2)                        [100, 5]
(%i3) df_table_names(T);
(%o3)           [id, name, price, qty, region]
```

See also: `df_read_parquet`, `df_read_json`, `df_write_csv`

### Function: df_read_parquet (path)

Read a Parquet file into a df_table.

#### Examples

```maxima
(%i1) T : df_read_parquet("/path/to/data.parquet")$
(%i2) df_table_shape(T);
(%o2)                        [1000, 4]
```

See also: `df_read_csv`, `df_write_parquet`

### Function: df_read_json (path)

Read a JSON file into a df_table. DuckDB auto-detects the JSON structure.

#### Examples

```maxima
(%i1) T : df_read_json("/path/to/data.json")$
(%i2) df_table_shape(T);
(%o2)                        [50, 3]
```

See also: `df_read_csv`, `df_read_parquet`

### Function: df_write_csv (T, path)

Write a df_table to a CSV file with header row.

#### Examples

```maxima
(%i1) T : df_table(["name", "score"],
                    [df_string_column(["Alice", "Bob"]), ndarray([95.0, 87.0])])$
(%i2) df_write_csv(T, "/tmp/output.csv");
(%o2)                         done
```

See also: `df_read_csv`, `df_write_parquet`

### Function: df_write_parquet (T, path)

Write a df_table to a Parquet file.

#### Examples

```maxima
(%i1) df_write_parquet(T, "/tmp/output.parquet");
(%o1)                         done
```

See also: `df_read_parquet`, `df_write_csv`

### Function: df_sql (query)

Execute an SQL query via DuckDB and return the result as a df_table. DuckDB can read files directly in SQL. Registered tables (via `df_register`) are available by name.

#### Examples

```maxima
(%i1) T : df_sql("SELECT * FROM read_csv('data.csv') WHERE price > 10")$
(%i2) df_table_shape(T);
(%o2)                        [42, 5]
(%i3) df_register(T, "sales")$
(%i4) R : df_sql("SELECT region, sum(price) AS total FROM sales GROUP BY region")$
(%i5) df_table_names(R);
(%o5)                    [region, total]
```

See also: `df_sql_run`, `df_register`

### Function: df_sql_run (query)

Execute a DuckDB SQL statement that produces no result (DDL, INSERT, etc.).

#### Examples

```maxima
(%i1) df_sql_run("CREATE TABLE temp AS SELECT * FROM read_csv('data.csv')")$
(%i2) T : df_sql("SELECT * FROM temp WHERE x > 0")$
```

See also: `df_sql`

### Function: df_register (T, name)

Register a df_table as a DuckDB table, making it available for SQL queries by name. Re-registering the same name replaces the previous registration.

#### Examples

```maxima
(%i1) T : df_table(["x", "y"],
                    [ndarray([1.0, 2.0, 3.0]), ndarray([10.0, 20.0, 30.0])])$
(%i2) df_register(T, "mydata");
(%o2)                         done
(%i3) R : df_sql("SELECT * FROM mydata WHERE x > 1")$
(%i4) df_table_shape(R);
(%o4)                        [2, 2]
```

See also: `df_unregister`, `df_sql`

### Function: df_unregister (name)

Remove a previously registered DuckDB table.

#### Examples

```maxima
(%i1) df_unregister("mydata");
(%o1)                         done
```

See also: `df_register`

### Function: df_duckdb_filter (T, where_clause)

Filter table rows using a DuckDB SQL WHERE clause. Faster than `df_filter` for large tables. Accepts SQL expressions, not Maxima lambdas.

#### Examples

```maxima
(%i1) T : df_table(["name", "price"],
                    [df_string_column(["A", "B", "C"]), ndarray([10.0, 30.0, 20.0])])$
(%i2) T2 : df_duckdb_filter(T, "price > 15")$
(%i3) df_table_shape(T2);
(%o3)                        [2, 2]
(%i4) df_duckdb_filter(T, "price > 15 AND name = 'B'")$
```

See also: `df_filter`, `df_duckdb_arrange`

### Function: df_duckdb_arrange (T, column) / df_duckdb_arrange (T, column, descending)

Sort table rows using DuckDB. Ascending by default; pass `descending` for reverse order.

#### Examples

```maxima
(%i1) T2 : df_duckdb_arrange(T, "price")$
(%i2) df_to_string_list(df_table_column(T2, "name"));
(%o2)                      [A, C, B]
(%i3) T3 : df_duckdb_arrange(T, "price", descending)$
(%i4) df_to_string_list(df_table_column(T3, "name"));
(%o4)                      [B, C, A]
```

See also: `df_arrange`, `df_duckdb_filter`

### Function: df_duckdb_join (T1, T2, key) / df_duckdb_join (T1, T2, key, left)

Join two tables using DuckDB. Inner join by default; pass `left` for a left join.

#### Examples

```maxima
(%i1) T1 : df_table(["id", "name"],
                     [df_string_column(["1", "2", "3"]),
                      df_string_column(["Alice", "Bob", "Charlie"])])$
(%i2) T2 : df_table(["id", "score"],
                     [df_string_column(["1", "2"]), ndarray([90.0, 80.0])])$
(%i3) df_table_shape(df_duckdb_join(T1, T2, "id"));
(%o3)                        [2, 3]
(%i4) df_table_shape(df_duckdb_join(T1, T2, "id", left));
(%o4)                        [3, 3]
```

See also: `df_inner_join`, `df_left_join`

### Function: df_duckdb_group_summarize (T, group_col, name1, expr1, ...)

Group and aggregate using DuckDB SQL. Takes alternating result-name / SQL-expression string pairs. Much faster than `df_group_by` + `df_summarize` for large tables.

#### Examples

```maxima
(%i1) T : df_table(["region", "revenue"],
                    [df_string_column(["N", "S", "N", "S", "N"]),
                     ndarray([10.0, 20.0, 30.0, 40.0, 50.0])])$
(%i2) R : df_duckdb_group_summarize(T, "region",
             "total", "sum(revenue)",
             "avg_rev", "avg(revenue)",
             "n", "count(*)")$
(%i3) df_table_shape(R);
(%o3)                        [2, 4]
(%i4) df_table_names(R);
(%o4)              [region, total, avg_rev, n]
```

See also: `df_group_by`, `df_summarize`

### Function: df_duckdb_status ()

Report whether the DuckDB connection is active. Returns `true` or `false`.

#### Examples

```maxima
(%i1) df_duckdb_status();
(%o1)                        false
(%i2) df_sql("SELECT 1")$
(%i3) df_duckdb_status();
(%o3)                         true
```

See also: `df_duckdb_close`

### Function: df_duckdb_close ()

Close the session DuckDB connection and database. The connection is automatically re-created on the next DuckDB operation.

#### Examples

```maxima
(%i1) df_duckdb_close();
(%o1)                         done
(%i2) df_duckdb_status();
(%o2)                        false
```

See also: `df_duckdb_status`
