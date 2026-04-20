;;; sql.lisp — Ad-hoc SQL queries via DuckDB

(in-package #:maxima)

(defun $df_sql (query-str)
  "Execute an SQL query via DuckDB and return a df_table.
   DuckDB can read files directly in SQL.
   Registered tables (via df_register) are available by name.
   df_sql(\"SELECT * FROM read_csv('data.csv') WHERE price > 10\")
   df_sql(\"SELECT region, sum(revenue) FROM sales GROUP BY region\")"
  (let ((sql ($sconcat query-str)))
    (df-with-duckdb
      (let ((result (duckdb:query sql nil)))
        (when (null result)
          (merror "df_sql: query returned no results"))
        (df-table-wrap (df-duckdb-result-to-table result))))))

(defun $df_sql_run (query-str)
  "Execute a DuckDB SQL statement that produces no result (DDL, INSERT, etc.).
   df_sql_run(\"CREATE TABLE temp AS SELECT * FROM read_csv('data.csv')\")"
  (let ((sql ($sconcat query-str)))
    (df-with-duckdb
      (duckdb:run sql))
    '$done))
