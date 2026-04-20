;;; joins.lisp — Table joins and binds

(in-package #:maxima)

;;; ---- Joins ----

(defun df-join-impl (tbl1 tbl2 key-name type)
  "Implement hash join. TYPE is :inner or :left."
  (let* ((t1 (df-table-unwrap tbl1))
         (t2 (df-table-unwrap tbl2))
         (key-str ($sconcat key-name))
         (names1 (dataframes:table-column-names t1))
         (names2 (dataframes:table-column-names t2))
         (cols1 (dataframes:table-columns t1))
         (cols2 (dataframes:table-columns t2))
         (nrows1 (dataframes:table-nrows t1))
         (pos1 (position key-str names1 :test #'string-equal))
         (pos2 (position key-str names2 :test #'string-equal)))
    (unless pos1
      (merror "df_~A_join: key column ~S not found in left table" type key-str))
    (unless pos2
      (merror "df_~A_join: key column ~S not found in right table" type key-str))
    (let* ((key-col2 (nth pos2 cols2))
           (key-col1 (nth pos1 cols1))
           ;; Build hash table on right table's key
           (right-idx (make-hash-table :test #'equal))
           ;; Non-key columns from right table
           (right-non-key-positions
             (loop for i below (length cols2) when (/= i pos2) collect i))
           (right-non-key-names
             (loop for i in right-non-key-positions collect (nth i names2)))
           (right-non-key-cols
             (loop for i in right-non-key-positions collect (nth i cols2))))
      ;; Index right table by key
      (dotimes (i (dataframes:table-nrows t2))
        (let ((key (etypecase key-col2
                     (numerics:ndarray
                      (magicl:tref (numerics:ndarray-tensor key-col2) i))
                     (dataframes:string-column
                      (aref (dataframes:string-column-data key-col2) i)))))
          (push i (gethash key right-idx '()))))
      ;; Reverse to maintain order
      (maphash (lambda (k v) (setf (gethash k right-idx) (nreverse v))) right-idx)
      ;; Scan left table and build matched row pairs
      (let ((left-rows '())
            (right-rows '()))
        (dotimes (i nrows1)
          (let* ((key (etypecase key-col1
                        (numerics:ndarray
                         (magicl:tref (numerics:ndarray-tensor key-col1) i))
                        (dataframes:string-column
                         (aref (dataframes:string-column-data key-col1) i))))
                 (matches (gethash key right-idx)))
            (cond
              (matches
               (dolist (j matches)
                 (push i left-rows)
                 (push j right-rows)))
              ((eq type :left)
               (push i left-rows)
               (push nil right-rows)))))
        (setf left-rows (nreverse left-rows))
        (setf right-rows (nreverse right-rows))
        (let* ((n (length left-rows))
               (left-idx-vec (coerce left-rows 'simple-vector))
               (right-idx-vec (coerce right-rows 'simple-vector))
               ;; Build result columns: all left columns + right non-key columns
               (result-names (append names1 right-non-key-names))
               (result-cols
                 (append
                  ;; Left columns (indexed by left-rows)
                  (loop for col in cols1
                        collect (df-join-take-col col n left-idx-vec))
                  ;; Right non-key columns (indexed by right-rows, nil = missing)
                  (loop for col in right-non-key-cols
                        collect (df-join-take-col-nullable col n right-idx-vec)))))
          (df-table-wrap
           (dataframes:make-table result-names result-cols)))))))

(defun df-join-take-col (col n idx-vec)
  "Extract rows from a column using index vector (no nulls)."
  (etypecase col
    (numerics:ndarray
     (let* ((tensor (numerics:ndarray-tensor col))
            (dtype (numerics:ndarray-dtype col))
            (eltype (ecase dtype
                      (:double-float 'double-float)
                      (:complex-double-float '(complex double-float))))
            (result (magicl:empty (list n) :type eltype :layout :column-major)))
       (dotimes (i n)
         (setf (magicl:tref result i)
               (magicl:tref tensor (svref idx-vec i))))
       (numerics:make-ndarray result :dtype dtype)))
    (dataframes:string-column
     (let* ((data (dataframes:string-column-data col))
            (new-data (make-array n)))
       (dotimes (i n)
         (setf (aref new-data i) (aref data (svref idx-vec i))))
       (dataframes:make-string-column new-data)))))

(defun df-join-take-col-nullable (col n idx-vec)
  "Extract rows from a column, nil indices produce NaN or empty string."
  (etypecase col
    (numerics:ndarray
     (let* ((tensor (numerics:ndarray-tensor col))
            (dtype (numerics:ndarray-dtype col))
            (eltype (ecase dtype
                      (:double-float 'double-float)
                      (:complex-double-float '(complex double-float))))
            (result (magicl:empty (list n) :type eltype :layout :column-major)))
       (dotimes (i n)
         (let ((idx (svref idx-vec i)))
           (setf (magicl:tref result i)
                 (if idx
                     (magicl:tref tensor idx)
                     (coerce 0 eltype)))))   ; 0 fill for unmatched
       (numerics:make-ndarray result :dtype dtype)))
    (dataframes:string-column
     (let* ((data (dataframes:string-column-data col))
            (new-data (make-array n :initial-element "")))
       (dotimes (i n)
         (let ((idx (svref idx-vec i)))
           (when idx
             (setf (aref new-data i) (aref data idx)))))
       (dataframes:make-string-column new-data)))))

(defun $df_inner_join (tbl1 tbl2 key-name)
  "Inner join two tables on a key column.
   df_inner_join(T1, T2, \"id\")"
  (df-join-impl tbl1 tbl2 key-name :inner))

(defun $df_left_join (tbl1 tbl2 key-name)
  "Left join two tables on a key column.
   Unmatched left rows get 0/\"\" fill for right columns.
   df_left_join(T1, T2, \"id\")"
  (df-join-impl tbl1 tbl2 key-name :left))

;;; ---- Binds ----

(defun $df_bind_rows (tbl1 tbl2)
  "Stack two tables vertically. Column names must match.
   df_bind_rows(T1, T2)"
  (let* ((t1 (df-table-unwrap tbl1))
         (t2 (df-table-unwrap tbl2))
         (names1 (dataframes:table-column-names t1))
         (names2 (dataframes:table-column-names t2))
         (cols1 (dataframes:table-columns t1))
         (cols2 (dataframes:table-columns t2))
         (n1 (dataframes:table-nrows t1))
         (n2 (dataframes:table-nrows t2)))
    (unless (equal names1 names2)
      (merror "df_bind_rows: column names must match. Left: ~A, Right: ~A"
              (format nil "~{~A~^, ~}" names1)
              (format nil "~{~A~^, ~}" names2)))
    (let ((new-cols
            (loop for c1 in cols1
                  for c2 in cols2
                  collect (etypecase c1
                            (numerics:ndarray
                             (let* ((t1t (numerics:ndarray-tensor c1))
                                    (t2t (numerics:ndarray-tensor c2))
                                    (dtype (numerics:ndarray-dtype c1))
                                    (eltype (ecase dtype
                                              (:double-float 'double-float)
                                              (:complex-double-float '(complex double-float))))
                                    (result (magicl:empty (list (+ n1 n2))
                                                          :type eltype
                                                          :layout :column-major)))
                               (dotimes (i n1)
                                 (setf (magicl:tref result i)
                                       (magicl:tref t1t i)))
                               (dotimes (i n2)
                                 (setf (magicl:tref result (+ n1 i))
                                       (magicl:tref t2t i)))
                               (numerics:make-ndarray result :dtype dtype)))
                            (dataframes:string-column
                             (let* ((d1 (dataframes:string-column-data c1))
                                    (d2 (dataframes:string-column-data c2))
                                    (new-data (make-array (+ n1 n2))))
                               (dotimes (i n1)
                                 (setf (aref new-data i) (aref d1 i)))
                               (dotimes (i n2)
                                 (setf (aref new-data (+ n1 i)) (aref d2 i)))
                               (dataframes:make-string-column new-data)))))))
      (df-table-wrap (dataframes:make-table names1 new-cols)))))

(defun $df_bind_cols (tbl1 tbl2)
  "Stack two tables horizontally. Row counts must match, no duplicate names.
   df_bind_cols(T1, T2)"
  (let* ((t1 (df-table-unwrap tbl1))
         (t2 (df-table-unwrap tbl2))
         (n1 (dataframes:table-nrows t1))
         (n2 (dataframes:table-nrows t2)))
    (unless (= n1 n2)
      (merror "df_bind_cols: row counts must match (~M vs ~M)" n1 n2))
    (let ((names1 (dataframes:table-column-names t1))
          (names2 (dataframes:table-column-names t2)))
      (dolist (n names2)
        (when (member n names1 :test #'string-equal)
          (merror "df_bind_cols: duplicate column name ~S" n)))
      (df-table-wrap
       (dataframes:make-table
        (append names1 names2)
        (append (dataframes:table-columns t1)
                (dataframes:table-columns t2)))))))
