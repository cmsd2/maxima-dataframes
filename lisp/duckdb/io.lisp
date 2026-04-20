;;; io.lisp — File I/O via DuckDB

(in-package #:maxima)

(defun $df_read_csv (path)
  "Read a CSV file into a df_table.
   DuckDB auto-detects column types and delimiter.
   df_read_csv(\"/path/to/data.csv\")"
  (let ((path-str ($sconcat path)))
    (df-with-duckdb
      (let ((result (duckdb:query
                     (format nil "SELECT * FROM read_csv('~A', auto_detect=true)"
                             path-str)
                     nil)))
        (when (null result)
          (merror "df_read_csv: no data returned from ~A" path-str))
        (df-table-wrap (df-duckdb-result-to-table result))))))

(defun $df_read_parquet (path)
  "Read a Parquet file into a df_table.
   df_read_parquet(\"/path/to/data.parquet\")"
  (let ((path-str ($sconcat path)))
    (df-with-duckdb
      (let ((result (duckdb:query
                     (format nil "SELECT * FROM read_parquet('~A')"
                             path-str)
                     nil)))
        (when (null result)
          (merror "df_read_parquet: no data returned from ~A" path-str))
        (df-table-wrap (df-duckdb-result-to-table result))))))

(defun $df_read_json (path)
  "Read a JSON file into a df_table.
   df_read_json(\"/path/to/data.json\")"
  (let ((path-str ($sconcat path)))
    (df-with-duckdb
      (let ((result (duckdb:query
                     (format nil "SELECT * FROM read_json('~A', auto_detect=true)"
                             path-str)
                     nil)))
        (when (null result)
          (merror "df_read_json: no data returned from ~A" path-str))
        (df-table-wrap (df-duckdb-result-to-table result))))))

(defun $df_write_csv (tbl path)
  "Write a df_table to a CSV file.
   df_write_csv(T, \"/path/to/output.csv\")"
  (let* ((path-str ($sconcat path))
         (temp-name (format nil "_df_write_~A" (random 1000000))))
    ($df_register tbl temp-name)
    (unwind-protect
         (df-with-duckdb
           (duckdb:run
            (format nil "COPY \"~A\" TO '~A' (FORMAT CSV, HEADER true)"
                    temp-name path-str)))
      ($df_unregister temp-name))
    '$done))

(defun $df_write_parquet (tbl path)
  "Write a df_table to a Parquet file.
   df_write_parquet(T, \"/path/to/output.parquet\")"
  (let* ((path-str ($sconcat path))
         (temp-name (format nil "_df_write_~A" (random 1000000))))
    ($df_register tbl temp-name)
    (unwind-protect
         (df-with-duckdb
           (duckdb:run
            (format nil "COPY \"~A\" TO '~A' (FORMAT PARQUET)"
                    temp-name path-str)))
      ($df_unregister temp-name))
    '$done))
