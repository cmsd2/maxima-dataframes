;;; register.lisp — df_table → DuckDB temp table registration

(in-package #:maxima)

(defvar *df-registered-tables* (make-hash-table :test #'equal)
  "Map from registration name (string) to DuckDB table name (string).
   Tracks which tables have been registered so they can be unregistered.")

(defun df-duckdb-create-and-populate (tbl-struct name-str)
  "Create a DuckDB table from a df_table struct using INSERT statements."
  (let* ((names (dataframes:table-column-names tbl-struct))
         (cols (dataframes:table-columns tbl-struct))
         (nrows (dataframes:table-nrows tbl-struct))
         (ncols (length cols))
         ;; Build CREATE TABLE with column types
         (col-defs
           (mapcar (lambda (name col)
                     (format nil "\"~A\" ~A" name
                             (etypecase col
                               (numerics:ndarray "DOUBLE")
                               (dataframes:string-column "VARCHAR"))))
                   names cols)))
    ;; Drop if exists, then create
    (duckdb:run (format nil "DROP TABLE IF EXISTS \"~A\"" name-str))
    (duckdb:run (format nil "CREATE TABLE \"~A\" (~{~A~^, ~})" name-str col-defs))
    ;; Insert rows in batches
    (when (> nrows 0)
      (let ((batch-size 1000))
        (loop for start from 0 below nrows by batch-size
              do (let* ((end (min (+ start batch-size) nrows))
                        (value-rows
                          (loop for i from start below end
                                collect
                                (format nil "(~{~A~^, ~})"
                                        (loop for col in cols
                                              collect (etypecase col
                                                        (numerics:ndarray
                                                         (let ((v (magicl:tref
                                                                   (numerics:ndarray-tensor col) i)))
                                                           (format nil "~F" (realpart v))))
                                                        (dataframes:string-column
                                                         (format nil "'~A'"
                                                                 (df-duckdb-sql-escape-string
                                                                  (aref (dataframes:string-column-data col) i))))))))))
                   (duckdb:run
                    (format nil "INSERT INTO \"~A\" VALUES ~{~A~^, ~}"
                            name-str value-rows))))))))

(defun df-duckdb-sql-escape-string (s)
  "Escape a string for SQL single-quoted literals."
  (with-output-to-string (out)
    (loop for ch across s
          do (if (char= ch #\')
                 (write-string "''" out)
                 (write-char ch out)))))

(defun $df_register (tbl name)
  "Register a df_table as a DuckDB table for SQL queries.
   df_register(T, \"sales\")"
  (let* ((t-struct (df-table-unwrap tbl))
         (name-str ($sconcat name)))
    (df-with-duckdb
      ;; Drop previous registration if exists
      (when (gethash name-str *df-registered-tables*)
        (duckdb:run (format nil "DROP TABLE IF EXISTS \"~A\"" name-str)))
      ;; Create and populate
      (df-duckdb-create-and-populate t-struct name-str)
      (setf (gethash name-str *df-registered-tables*) name-str))
    '$done))

(defun $df_unregister (name)
  "Unregister a previously registered DuckDB table.
   df_unregister(\"sales\")"
  (let ((name-str ($sconcat name)))
    (when (gethash name-str *df-registered-tables*)
      (df-with-duckdb
        (duckdb:run (format nil "DROP TABLE IF EXISTS \"~A\"" name-str)))
      (remhash name-str *df-registered-tables*))
    '$done))
