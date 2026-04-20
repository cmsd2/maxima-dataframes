;;; dataframes.asd — ASDF system definitions for dataframes

(defsystem "dataframes"
  :description "Pandas-like tabular data for Maxima"
  :version "0.1.0"
  :license "MIT"
  :depends-on ("alexandria")
  :serial t
  :components
  ((:file "packages")
   (:file "string-column")
   (:file "table")
   (:file "describe")
   (:file "manipulate")
   (:file "groupby")
   (:file "joins")
   (:file "display")))

(defsystem "dataframes-duckdb"
  :description "DuckDB integration for dataframes: I/O, SQL, accelerated ops"
  :version "0.1.0"
  :license "MIT"
  :depends-on ("dataframes" "duckdb")
  :serial t
  :components
  ((:module "duckdb"
    :serial t
    :components
    ((:file "connection")
     (:file "convert")
     (:file "register")
     (:file "io")
     (:file "sql")
     (:file "accel")))))
