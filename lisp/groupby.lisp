;;; groupby.lisp — Grouped tables and grouped operations

(in-package #:dataframes)

(defstruct (grouped-table
            (:constructor %make-grouped-table)
            (:print-function print-grouped-table))
  "A table grouped by a column. Stores precomputed group keys and row indices."
  (table nil :type table)
  (group-column "" :type string)
  (group-keys #() :type simple-vector)
  (group-indices nil :type list))   ; list of simple-vectors of row indices

(defun print-grouped-table (obj stream depth)
  (declare (ignore depth))
  (format stream "#<grouped-table ~D groups by ~S>"
          (length (grouped-table-group-keys obj))
          (grouped-table-group-column obj)))

;;; Maxima-level API

(in-package #:maxima)

(defun $df_grouped_table_p (x)
  "Predicate: is X a grouped-table handle?"
  (and (listp x)
       (listp (car x))
       (eq (caar x) '$df_grouped_table)
       (typep (cadr x) 'dataframes:grouped-table)))

(defun df-grouped-table-unwrap (x)
  "Extract the Lisp grouped-table struct from a Maxima expression."
  (unless ($df_grouped_table_p x)
    (merror "Expected a df_grouped_table, got: ~M" x))
  (cadr x))

(defun df-grouped-table-wrap (gt)
  "Wrap a Lisp grouped-table struct into a Maxima expression."
  `(($df_grouped_table simp) ,gt))

(defun $df_group_by (tbl col-name)
  "Group a table by a column.
   df_group_by(T, \"region\")"
  (let* ((t-struct (df-table-unwrap tbl))
         (name-str ($sconcat col-name))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (pos (position name-str names :test #'string-equal))
         (nrows (dataframes:table-nrows t-struct)))
    (unless pos
      (merror "df_group_by: column ~S not found" name-str))
    (let* ((group-col (nth pos cols))
           (key-order '())
           (key-to-rows (make-hash-table :test #'equal)))
      ;; Scan rows and collect indices per group key
      (dotimes (i nrows)
        (let ((key (etypecase group-col
                     (numerics:ndarray
                      (magicl:tref (numerics:ndarray-tensor group-col) i))
                     (dataframes:string-column
                      (aref (dataframes:string-column-data group-col) i)))))
          (unless (gethash key key-to-rows)
            (push key key-order))
          (push i (gethash key key-to-rows '()))))
      ;; Reverse to preserve original order
      (let* ((keys (nreverse key-order))
             (key-vec (coerce keys 'simple-vector))
             (indices (mapcar (lambda (k)
                                (coerce (nreverse (gethash k key-to-rows))
                                        'simple-vector))
                              keys)))
        (df-grouped-table-wrap
         (dataframes:%make-grouped-table
          :table t-struct
          :group-column name-str
          :group-keys key-vec
          :group-indices indices))))))

(defun df-grouped-summarize (grouped-tbl &rest args)
  "Apply df_summarize to each group and combine results.
   Called from $df_summarize when input is a grouped-table."
  (let* ((gt (df-grouped-table-unwrap grouped-tbl))
         (t-struct (dataframes:grouped-table-table gt))
         (group-col-name (dataframes:grouped-table-group-column gt))
         (group-keys (dataframes:grouped-table-group-keys gt))
         (group-indices (dataframes:grouped-table-group-indices gt))
         (ngroups (length group-keys)))
    (unless (evenp (length args))
      (merror "df_summarize: expected alternating name/lambda pairs"))
    ;; Process each name/lambda pair across all groups
    (let* ((npairs (/ (length args) 2))
           (summary-names (loop for (name fn) on args by #'cddr
                                collect ($sconcat name)))
           (summary-fns (loop for (name fn) on args by #'cddr
                              collect fn))
           ;; For each summary column, collect values across groups
           (summary-values (make-array npairs :initial-element nil)))
      (dotimes (g ngroups)
        ;; Build a sub-table for this group
        (let* ((row-idxs (coerce (nth g group-indices) 'list))
               (sub-table (df-table-take-rows t-struct row-idxs))
               (sub-names (dataframes:table-column-names sub-table))
               (sub-cols (dataframes:table-columns sub-table)))
          ;; Apply each summary function to the sub-table
          (loop for fn in summary-fns
                for s from 0
                do (let* ((param-names (df-extract-param-names fn))
                          (col-handles
                            (mapcar (lambda (pname)
                                      (let ((p (position pname sub-names
                                                         :test #'string-equal)))
                                        (unless p
                                          (merror "df_summarize: column ~S not found" pname))
                                        (df-wrap-column (nth p sub-cols))))
                                    param-names))
                          (result (mlambda fn col-handles nil t nil)))
                     (push result (aref summary-values s))))))
      ;; Build result table: group-key column + summary columns
      (let* ((key-col (let ((first-key (svref group-keys 0)))
                        (etypecase first-key
                          (string
                           (dataframes:make-string-column
                            (coerce (coerce group-keys 'list) 'simple-vector)))
                          (number
                           (let ((tensor (magicl:empty (list ngroups)
                                                       :type 'double-float
                                                       :layout :column-major)))
                             (dotimes (i ngroups)
                               (setf (magicl:tref tensor i)
                                     (coerce (realpart (svref group-keys i))
                                             'double-float)))
                             (numerics:make-ndarray tensor))))))
             (result-names (cons group-col-name summary-names))
             (result-cols
               (cons key-col
                     (loop for s below npairs
                           collect (let* ((vals (nreverse (aref summary-values s)))
                                          (first-val (first vals)))
                                     (cond
                                       ((or (numberp first-val)
                                            (and (consp first-val)
                                                 (eq (caar first-val) 'rat)))
                                        (let ((tensor (magicl:empty (list ngroups)
                                                                    :type 'double-float
                                                                    :layout :column-major)))
                                          (loop for val in vals
                                                for i from 0
                                                do (setf (magicl:tref tensor i)
                                                         (coerce ($float val) 'double-float)))
                                          (numerics:make-ndarray tensor)))
                                       ((stringp first-val)
                                        (dataframes:make-string-column
                                         (coerce vals 'simple-vector)))
                                       (t
                                        (let ((tensor (magicl:empty (list ngroups)
                                                                    :type 'double-float
                                                                    :layout :column-major)))
                                          (loop for val in vals
                                                for i from 0
                                                do (setf (magicl:tref tensor i)
                                                         (coerce ($float val) 'double-float)))
                                          (numerics:make-ndarray tensor)))))))))
        (df-table-wrap
         (dataframes:make-table result-names result-cols))))))

;;; Display

(displa-def $df_grouped_table dim-$df_grouped_table)

(defun dim-$df_grouped_table (form result)
  "Display a grouped table."
  (let ((gt (cadr form)))
    (if (typep gt 'dataframes:grouped-table)
        (let* ((ngroups (length (dataframes:grouped-table-group-keys gt)))
               (t-struct (dataframes:grouped-table-table gt))
               (nrows (dataframes:table-nrows t-struct))
               (ncols (length (dataframes:table-columns t-struct)))
               (gcol (dataframes:grouped-table-group-column gt)))
          (dimension-function
           `((mprogn) ,(format nil "df_grouped_table: ~D rows x ~D cols, ~D groups by ~S"
                               nrows ncols ngroups gcol))
           result))
        (dimension-function form result))))
