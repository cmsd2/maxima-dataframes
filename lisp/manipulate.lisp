;;; manipulate.lisp — dplyr-style table manipulation verbs

(in-package #:maxima)

;;; ---- Shared helpers ----

(defun df-extract-param-names (pred)
  "Extract column names from a Maxima lambda's parameter list.
   lambda([price,qty], ...) → (\"price\" \"qty\")"
  (unless (numerics-lambda-p pred)
    (merror "expected a lambda expression, got: ~M" pred))
  (let ((params (cdadr pred)))
    (mapcar (lambda (sym)
              (string-downcase (subseq (symbol-name sym) 1)))
            params)))

(defun df-resolve-param-cols (param-names t-struct)
  "Map parameter name strings to column objects.
   Returns a list of column objects in the same order as param-names."
  (let ((names (dataframes:table-column-names t-struct))
        (cols (dataframes:table-columns t-struct)))
    (mapcar (lambda (pname)
              (let ((pos (position pname names :test #'string-equal)))
                (unless pos
                  (merror "column ~S not found. Available: ~A"
                          pname (format nil "~{~A~^, ~}" names)))
                (nth pos cols)))
            param-names)))

(defun df-row-value (col row)
  "Extract a row value from a column, converting to Maxima form."
  (etypecase col
    (numerics:ndarray
     (lisp-to-maxima-number (magicl:tref (numerics:ndarray-tensor col) row)))
    (dataframes:string-column
     (aref (dataframes:string-column-data col) row))))

(defun df-table-take-rows (t-struct row-indices)
  "Build a new table struct with only the given row indices.
   row-indices is a list of 0-based integer indices."
  (let* ((names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (n (length row-indices)))
    (if (zerop n)
        ;; Empty table: create empty columns
        (let ((new-cols
                (loop for col in cols
                      collect (etypecase col
                                (numerics:ndarray
                                 (let* ((dtype (numerics:ndarray-dtype col))
                                        (eltype (ecase dtype
                                                  (:double-float 'double-float)
                                                  (:complex-double-float '(complex double-float)))))
                                   (numerics:make-ndarray
                                    (magicl:empty '(1) :type eltype :layout :column-major)
                                    :dtype dtype)))
                                (dataframes:string-column
                                 (dataframes:make-string-column #()))))))
          ;; Use 0 for nrows since make-table derives from first col
          (dataframes::%make-table :column-names names :columns new-cols :nrows 0))
        ;; Normal case
        (let ((idx-vec (coerce row-indices 'simple-vector)))
          (let ((new-cols
                  (loop for col in cols
                        collect (etypecase col
                                  (numerics:ndarray
                                   (let* ((tensor (numerics:ndarray-tensor col))
                                          (dtype (numerics:ndarray-dtype col))
                                          (eltype (ecase dtype
                                                    (:double-float 'double-float)
                                                    (:complex-double-float '(complex double-float))))
                                          (result (magicl:empty (list n)
                                                                :type eltype
                                                                :layout :column-major)))
                                     (dotimes (i n)
                                       (setf (magicl:tref result i)
                                             (magicl:tref tensor (svref idx-vec i))))
                                     (numerics:make-ndarray result :dtype dtype)))
                                  (dataframes:string-column
                                   (let* ((data (dataframes:string-column-data col))
                                          (new-data (make-array n)))
                                     (dotimes (i n)
                                       (setf (aref new-data i) (aref data (svref idx-vec i))))
                                     (dataframes:make-string-column new-data)))))))
            (dataframes:make-table names new-cols))))))

(defun df-apply-row-lambda (pred param-cols row)
  "Apply a Maxima lambda to column values at the given row index."
  (let ((args (mapcar (lambda (col) (df-row-value col row)) param-cols)))
    (mlambda pred args nil nil nil)))

;;; ---- Phase 2: filter, select, arrange ----

(defun $df_filter (tbl pred)
  "Subset rows where pred returns true.
   Lambda parameter names are matched to column names.
   df_filter(T, lambda([price], is(price > 30)))"
  (let* ((t-struct (df-table-unwrap tbl))
         (nrows (dataframes:table-nrows t-struct))
         (param-names (df-extract-param-names pred))
         (param-cols (df-resolve-param-cols param-names t-struct))
         (matching-rows
           (loop for i below nrows
                 when (df-apply-row-lambda pred param-cols i)
                 collect i)))
    (df-table-wrap (df-table-take-rows t-struct matching-rows))))

(defun $df_select (tbl names)
  "Subset and/or reorder columns by name.
   df_select(T, [\"price\", \"name\"])"
  (unless ($listp names)
    (merror "df_select: expected a list of column names"))
  (let* ((t-struct (df-table-unwrap tbl))
         (name-list (mapcar #'$sconcat (cdr names)))
         (all-names (dataframes:table-column-names t-struct))
         (all-cols (dataframes:table-columns t-struct))
         (selected-names '())
         (selected-cols '()))
    (dolist (n name-list)
      (let ((pos (position n all-names :test #'string-equal)))
        (unless pos
          (merror "df_select: column ~S not found. Available: ~A"
                  n (format nil "~{~A~^, ~}" all-names)))
        (push n selected-names)
        (push (nth pos all-cols) selected-cols)))
    (df-table-wrap
     (dataframes:make-table (nreverse selected-names)
                            (nreverse selected-cols)))))

(defun $df_arrange (tbl col-name &optional direction)
  "Sort rows by a column.
   df_arrange(T, \"price\")              — ascending
   df_arrange(T, \"price\", descending)  — descending"
  (let* ((t-struct (df-table-unwrap tbl))
         (name-str ($sconcat col-name))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (pos (position name-str names :test #'string-equal))
         (nrows (dataframes:table-nrows t-struct)))
    (unless pos
      (merror "df_arrange: column ~S not found" name-str))
    (let* ((sort-col (nth pos cols))
           (indices (make-array nrows :element-type 'fixnum))
           (desc-p (eq direction '$descending)))
      ;; Build index array
      (dotimes (i nrows) (setf (aref indices i) i))
      ;; Sort indices by column values
      (etypecase sort-col
        (numerics:ndarray
         (let ((tensor (numerics:ndarray-tensor sort-col)))
           (setf indices
                 (stable-sort indices
                              (if desc-p
                                  (lambda (a b)
                                    (> (realpart (magicl:tref tensor a))
                                       (realpart (magicl:tref tensor b))))
                                  (lambda (a b)
                                    (< (realpart (magicl:tref tensor a))
                                       (realpart (magicl:tref tensor b)))))))))
        (dataframes:string-column
         (let ((data (dataframes:string-column-data sort-col)))
           (setf indices
                 (stable-sort indices
                              (if desc-p
                                  (lambda (a b) (string> (aref data a) (aref data b)))
                                  (lambda (a b) (string< (aref data a) (aref data b)))))))))
      (df-table-wrap
       (df-table-take-rows t-struct (coerce indices 'list))))))

(defun $df_slice (tbl indices)
  "Subset rows by position (1-indexed).
   df_slice(T, [1, 3, 5])"
  (unless ($listp indices)
    (merror "df_slice: expected a list of indices"))
  (let* ((t-struct (df-table-unwrap tbl))
         (nrows (dataframes:table-nrows t-struct))
         (idx-list (mapcar (lambda (i)
                             (unless (and (integerp i) (>= i 1) (<= i nrows))
                               (merror "df_slice: index ~M out of bounds [1, ~M]" i nrows))
                             (1- i))
                           (cdr indices))))
    (df-table-wrap (df-table-take-rows t-struct idx-list))))

(defun $df_rename (tbl old-name new-name)
  "Rename a column.
   df_rename(T, \"old\", \"new\")"
  (let* ((t-struct (df-table-unwrap tbl))
         (old-str ($sconcat old-name))
         (new-str ($sconcat new-name))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (pos (position old-str names :test #'string-equal)))
    (unless pos
      (merror "df_rename: column ~S not found" old-str))
    (let ((new-names (copy-list names)))
      (setf (nth pos new-names) new-str)
      (df-table-wrap (dataframes:make-table new-names cols)))))

;;; ---- Phase 3: mutate, summarize ----

(defun $df_mutate (tbl col-name pred)
  "Add or replace a column by applying a lambda row-wise.
   Lambda parameter names are matched to column names.
   df_mutate(T, \"total\", lambda([price, qty], price * qty))"
  (let* ((t-struct (df-table-unwrap tbl))
         (nrows (dataframes:table-nrows t-struct))
         (name-str ($sconcat col-name))
         (param-names (df-extract-param-names pred))
         (param-cols (df-resolve-param-cols param-names t-struct))
         ;; Compute all result values
         (results (loop for i below nrows
                        collect (df-apply-row-lambda pred param-cols i))))
    ;; Determine result column type from first element
    (let* ((first-val (first results))
           (new-col
             (cond
               ((or (null results) (numberp first-val) (and (consp first-val) (eq (caar first-val) 'rat)))
                ;; Numeric result → ndarray
                (let ((tensor (magicl:empty (list nrows) :type 'double-float
                                                         :layout :column-major)))
                  (loop for val in results
                        for i from 0
                        do (setf (magicl:tref tensor i)
                                 (coerce (maxima-to-lisp-number val :double-float)
                                         'double-float)))
                  (numerics:make-ndarray tensor)))
               ((stringp first-val)
                ;; String result → string-column
                (dataframes:make-string-column
                 (coerce (mapcar (lambda (v) ($sconcat v)) results) 'simple-vector)))
               (t
                ;; Try as numeric
                (let ((tensor (magicl:empty (list nrows) :type 'double-float
                                                         :layout :column-major)))
                  (loop for val in results
                        for i from 0
                        do (setf (magicl:tref tensor i)
                                 (coerce ($float val) 'double-float)))
                  (numerics:make-ndarray tensor)))))
           ;; Build new column lists
           (old-names (dataframes:table-column-names t-struct))
           (old-cols (dataframes:table-columns t-struct))
           (pos (position name-str old-names :test #'string-equal)))
      (if pos
          ;; Replace existing column
          (let ((new-cols (copy-list old-cols)))
            (setf (nth pos new-cols) new-col)
            (df-table-wrap (dataframes:make-table old-names new-cols)))
          ;; Append new column
          (df-table-wrap
           (dataframes:make-table (append old-names (list name-str))
                                  (append old-cols (list new-col))))))))

(defun $df_summarize (tbl &rest args)
  "Reduce columns to scalars. Takes alternating name/lambda pairs.
   Each lambda receives whole columns (as handles), not row values.
   df_summarize(T, \"avg\", lambda([price], np_mean(price)),
                   \"n\",   lambda([price], df_count(price)))"
  (let ((input-is-grouped ($df_grouped_table_p tbl)))
    (when input-is-grouped
      (return-from $df_summarize
        (apply #'df-grouped-summarize tbl args)))
    (let* ((t-struct (df-table-unwrap tbl))
           (all-names (dataframes:table-column-names t-struct))
           (all-cols (dataframes:table-columns t-struct)))
      (unless (evenp (length args))
        (merror "df_summarize: expected alternating name/lambda pairs"))
      (let ((result-names '())
            (result-cols '()))
        (loop for (name fn) on args by #'cddr
              do (let* ((name-str ($sconcat name))
                        (param-names (df-extract-param-names fn))
                        ;; Resolve params to columns and wrap as Maxima handles
                        (col-handles
                          (mapcar (lambda (pname)
                                    (let ((pos (position pname all-names
                                                         :test #'string-equal)))
                                      (unless pos
                                        (merror "df_summarize: column ~S not found" pname))
                                      (df-wrap-column (nth pos all-cols))))
                                  param-names))
                        ;; Call lambda with column handles (noeval=t to prevent re-evaluation)
                        (result (mlambda fn col-handles nil t nil)))
                   (push name-str result-names)
                   (push
                    (cond
                      ((or (numberp result)
                           (and (consp result) (eq (caar result) 'rat)))
                       (let ((tensor (magicl:empty '(1) :type 'double-float
                                                        :layout :column-major)))
                         (setf (magicl:tref tensor 0)
                               (coerce ($float result) 'double-float))
                         (numerics:make-ndarray tensor)))
                      ((integerp result)
                       (let ((tensor (magicl:empty '(1) :type 'double-float
                                                        :layout :column-major)))
                         (setf (magicl:tref tensor 0)
                               (coerce result 'double-float))
                         (numerics:make-ndarray tensor)))
                      ((stringp result)
                       (dataframes:make-string-column
                        (make-array 1 :initial-element result)))
                      (t
                       (let ((tensor (magicl:empty '(1) :type 'double-float
                                                        :layout :column-major)))
                         (setf (magicl:tref tensor 0)
                               (coerce ($float result) 'double-float))
                         (numerics:make-ndarray tensor))))
                    result-cols)))
        (df-table-wrap
         (dataframes:make-table (nreverse result-names)
                                (nreverse result-cols)))))))

;;; ---- df_distinct ----

(defun df-row-key (cols row)
  "Build a composite string key for a row across all columns."
  (format nil "~{~A~^|~}"
          (mapcar (lambda (col)
                    (etypecase col
                      (numerics:ndarray
                       (format nil "~A" (magicl:tref (numerics:ndarray-tensor col) row)))
                      (dataframes:string-column
                       (aref (dataframes:string-column-data col) row))))
                  cols)))

(defun $df_distinct (tbl &optional col-names)
  "Unique rows. Optionally specify columns to consider.
   df_distinct(T)              — all columns
   df_distinct(T, [\"name\"])  — by specific columns"
  (let* ((t-struct (df-table-unwrap tbl))
         (nrows (dataframes:table-nrows t-struct))
         (all-names (dataframes:table-column-names t-struct))
         (all-cols (dataframes:table-columns t-struct))
         ;; Determine which columns to use for uniqueness
         (key-cols (if (and col-names ($listp col-names))
                       (mapcar (lambda (n)
                                 (let* ((ns ($sconcat n))
                                        (pos (position ns all-names
                                                       :test #'string-equal)))
                                   (unless pos
                                     (merror "df_distinct: column ~S not found" ns))
                                   (nth pos all-cols)))
                               (cdr col-names))
                       all-cols))
         (seen (make-hash-table :test #'equal))
         (unique-rows '()))
    (dotimes (i nrows)
      (let ((key (df-row-key key-cols i)))
        (unless (gethash key seen)
          (setf (gethash key seen) t)
          (push i unique-rows))))
    (df-table-wrap
     (df-table-take-rows t-struct (nreverse unique-rows)))))
