;;; connection.lisp — Session-level DuckDB connection management

(in-package #:maxima)

(defvar *df-duckdb-database* nil
  "Session-level DuckDB database handle (lazy init, in-memory).")

(defvar *df-duckdb-connection* nil
  "Session-level DuckDB connection handle (lazy init).")

(defun df-duckdb-ensure-connection ()
  "Lazily initialize the DuckDB database and connection.
   Returns the connection object."
  (unless *df-duckdb-database*
    (setf *df-duckdb-database* (duckdb:open-database)))
  (unless *df-duckdb-connection*
    (setf *df-duckdb-connection*
          (duckdb:connect *df-duckdb-database*)))
  *df-duckdb-connection*)

(defmacro df-with-duckdb (&body body)
  "Execute BODY with DuckDB connection bound.
   Ensures connection exists and binds duckdb:*connection*."
  `(let ((duckdb:*connection* (df-duckdb-ensure-connection)))
     ,@body))

(defun $df_duckdb_close ()
  "Close the session DuckDB connection and database.
   df_duckdb_close()"
  (when *df-duckdb-connection*
    (duckdb:disconnect *df-duckdb-connection*)
    (setf *df-duckdb-connection* nil))
  (when *df-duckdb-database*
    (duckdb:close-database *df-duckdb-database*)
    (setf *df-duckdb-database* nil))
  '$done)

(defun $df_duckdb_status ()
  "Report whether DuckDB connection is active.
   df_duckdb_status() => true or false"
  (if *df-duckdb-connection* t nil))
