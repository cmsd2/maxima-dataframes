;;; accel.lisp — DuckDB-accelerated table operations

(in-package #:maxima)

(defun df-duckdb-with-temp-table (tbl fn)
  "Register TBL under a temp name, call FN with the name, clean up.
   Returns whatever FN returns."
  (let ((temp-name (format nil "_df_tmp_~A" (random 1000000))))
    ($df_register tbl temp-name)
    (unwind-protect (funcall fn temp-name)
      ($df_unregister temp-name))))

(defun df-duckdb-query-or-empty (sql tbl-struct)
  "Execute SQL query, return df_table. If empty result, return empty table
   with same schema as TBL-STRUCT."
  (df-with-duckdb
    (let ((result (duckdb:query sql nil)))
      (if result
          (df-table-wrap (df-duckdb-result-to-table result))
          ;; Empty result: preserve schema
          (let* ((names (dataframes:table-column-names tbl-struct))
                 (cols (mapcar (lambda (col)
                                 (etypecase col
                                   (numerics:ndarray
                                    (numerics:make-ndarray
                                     (magicl:empty '(0) :type 'double-float
                                                        :layout :column-major)))
                                   (dataframes:string-column
                                    (dataframes:make-string-column #()))))
                               (dataframes:table-columns tbl-struct))))
            (df-table-wrap
             (dataframes::%make-table
              :column-names names :columns cols :nrows 0)))))))

(defun $df_duckdb_filter (tbl predicate-sql)
  "Filter table rows using a DuckDB SQL WHERE clause.
   Much faster than df_filter for large tables.
   df_duckdb_filter(T, \"price > 30 AND region = 'North'\")"
  (let ((t-struct (df-table-unwrap tbl))
        (where-str ($sconcat predicate-sql)))
    (df-duckdb-with-temp-table tbl
      (lambda (temp-name)
        (df-duckdb-query-or-empty
         (format nil "SELECT * FROM \"~A\" WHERE ~A" temp-name where-str)
         t-struct)))))

(defun $df_duckdb_arrange (tbl col-name &optional direction)
  "Sort table using DuckDB.
   df_duckdb_arrange(T, \"price\")
   df_duckdb_arrange(T, \"price\", descending)"
  (let ((t-struct (df-table-unwrap tbl))
        (col-str ($sconcat col-name))
        (dir (if (eq direction '$descending) "DESC" "ASC")))
    (df-duckdb-with-temp-table tbl
      (lambda (temp-name)
        (df-duckdb-query-or-empty
         (format nil "SELECT * FROM \"~A\" ORDER BY \"~A\" ~A"
                 temp-name col-str dir)
         t-struct)))))

(defun $df_duckdb_join (tbl1 tbl2 key-name &optional (join-type '$inner))
  "Join two tables using DuckDB.
   df_duckdb_join(T1, T2, \"id\")           — inner join
   df_duckdb_join(T1, T2, \"id\", left)     — left join"
  (let ((key-str ($sconcat key-name))
        (join-keyword (ecase join-type
                        ($inner "INNER")
                        ($left "LEFT"))))
    (let ((temp1 (format nil "_df_jl_~A" (random 1000000)))
          (temp2 (format nil "_df_jr_~A" (random 1000000))))
      ($df_register tbl1 temp1)
      ($df_register tbl2 temp2)
      (unwind-protect
           (df-with-duckdb
             (let ((result (duckdb:query
                            (format nil "SELECT * FROM \"~A\" ~A JOIN \"~A\" USING (\"~A\")"
                                    temp1 join-keyword temp2 key-str)
                            nil)))
               (if result
                   (df-table-wrap (df-duckdb-result-to-table result))
                   (merror "df_duckdb_join: join returned no results"))))
        ($df_unregister temp1)
        ($df_unregister temp2)))))

(defun $df_duckdb_group_summarize (tbl group-col-name &rest agg-specs)
  "Group and aggregate using DuckDB SQL.
   Much faster than df_group_by + df_summarize for large tables.

   agg-specs are alternating result-name/sql-expression strings:
   df_duckdb_group_summarize(T, \"region\",
     \"total\", \"sum(revenue)\",
     \"avg_price\", \"avg(price)\")"
  (let ((group-str ($sconcat group-col-name)))
    (unless (evenp (length agg-specs))
      (merror "df_duckdb_group_summarize: expected alternating name/expression pairs"))
    (df-duckdb-with-temp-table tbl
      (lambda (temp-name)
        (let* ((select-parts
                 (cons (format nil "\"~A\"" group-str)
                       (loop for (name expr) on agg-specs by #'cddr
                             collect (format nil "~A AS \"~A\""
                                             ($sconcat expr)
                                             ($sconcat name)))))
               (sql (format nil "SELECT ~{~A~^, ~} FROM \"~A\" GROUP BY \"~A\""
                            select-parts temp-name group-str)))
          (df-with-duckdb
            (let ((result (duckdb:query sql nil)))
              (if result
                  (df-table-wrap (df-duckdb-result-to-table result))
                  (merror "df_duckdb_group_summarize: query returned no results")))))))))
