;;; table.lisp — Columnar table type (named typed columns)
;;; Migrated from numerics and extended for mixed column types.

(in-package #:dataframes)

(defstruct (table (:constructor %make-table))
  "A columnar table: named typed columns.
   Columns can be ndarray handles or string-column structs."
  (column-names nil :type list)
  (columns nil :type list)    ; list of ndarray or string-column
  (nrows 0 :type fixnum))

(defun column-nrows (col)
  "Get the number of rows in a column (ndarray or string-column)."
  (etypecase col
    (numerics:ndarray
     (first (magicl:shape (numerics:ndarray-tensor col))))
    (string-column
     (string-column-length col))))

(defun make-table (names columns)
  "Create a table from column names and columns (ndarray or string-column)."
  (assert (= (length names) (length columns)))
  (let ((nrows (if columns (column-nrows (first columns)) 0)))
    (%make-table :column-names names :columns columns :nrows nrows)))

;;; Maxima-level table API

(in-package #:maxima)

(defun $df_table_p (x)
  "Predicate: is X a table handle?"
  (and (listp x)
       (listp (car x))
       (eq (caar x) '$df_table)
       (typep (cadr x) 'dataframes:table)))

(defun df-table-unwrap (x)
  "Extract the Lisp table struct from a Maxima table expression."
  (unless ($df_table_p x)
    (merror "Expected a df_table, got: ~M" x))
  (cadr x))

(defun df-table-wrap (tbl)
  "Wrap a Lisp table struct into a Maxima expression."
  `(($df_table simp) ,tbl))

(defun df-unwrap-column (x)
  "Extract a Lisp column (ndarray or string-column) from a Maxima expression."
  (cond
    (($ndarray_p x)        (numerics-unwrap x))
    (($string_column_p x)  (string-column-unwrap x))
    (t (merror "Expected an ndarray or string_column, got: ~M" x))))

(defun df-wrap-column (col)
  "Wrap a Lisp column (ndarray or string-column) into a Maxima expression."
  (etypecase col
    (numerics:ndarray          (numerics-wrap col))
    (dataframes:string-column  (string-column-wrap col))))

(defun $df_table (names columns)
  "Create a table from column names and columns (ndarrays and/or string-columns).
   df_table([\"name\", \"value\"], [string_col, ndarray])"
  (unless (and ($listp names) ($listp columns))
    (merror "df_table: expected lists for names and columns"))
  (let ((name-list (mapcar #'$sconcat (cdr names)))
        (col-list (mapcar #'df-unwrap-column (cdr columns))))
    (df-table-wrap (dataframes:make-table name-list col-list))))

(defun $df_table_column (tbl name)
  "Extract a column by name: df_table_column(T, \"price\")"
  (let* ((t-struct (df-table-unwrap tbl))
         (name-str ($sconcat name))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (pos (position name-str names :test #'string=)))
    (unless pos
      (merror "df_table_column: column ~M not found. Available: ~M"
              name-str (format nil "~{~A~^, ~}" names)))
    (df-wrap-column (nth pos cols))))

(defun $df_table_to_ndarray (tbl)
  "Stack all numeric columns into a 2D ndarray: df_table_to_ndarray(T)
   Non-numeric columns are skipped."
  (let* ((t-struct (df-table-unwrap tbl))
         (cols (dataframes:table-columns t-struct))
         (nrows (dataframes:table-nrows t-struct))
         (num-cols (remove-if-not (lambda (c) (typep c 'numerics:ndarray)) cols))
         (ncols (length num-cols)))
    (when (zerop ncols)
      (merror "df_table_to_ndarray: table has no numeric columns"))
    (let ((result (magicl:empty (list nrows ncols)
                                :type 'double-float :layout :column-major)))
      (loop for col in num-cols
            for j from 0
            do (let ((tensor (numerics:ndarray-tensor col)))
                 (dotimes (i nrows)
                   (setf (magicl:tref result i j) (magicl:tref tensor i)))))
      (numerics-wrap (numerics:make-ndarray result)))))

(defun $df_ndarray_to_table (a names)
  "Split a 2D ndarray into named columns: df_ndarray_to_table(A, [\"x\", \"y\"])"
  (let* ((handle (numerics-unwrap a))
         (tensor (numerics:ndarray-tensor handle))
         (shape (magicl:shape tensor))
         (nrow (first shape))
         (ncol (second shape))
         (name-list (mapcar #'$sconcat (cdr names))))
    (unless (= ncol (length name-list))
      (merror "df_ndarray_to_table: ~D columns but ~D names"
              ncol (length name-list)))
    (let ((columns
            (loop for j below ncol
                  collect (let ((col (magicl:empty (list nrow) :type 'double-float)))
                            (dotimes (i nrow)
                              (setf (magicl:tref col i) (magicl:tref tensor i j)))
                            (numerics:make-ndarray col)))))
      (df-table-wrap (dataframes:make-table name-list columns)))))

(defun $df_table_shape (tbl)
  "Shape of table: df_table_shape(T) => [nrows, ncols]"
  (let ((t-struct (df-table-unwrap tbl)))
    `((mlist simp)
      ,(dataframes:table-nrows t-struct)
      ,(length (dataframes:table-columns t-struct)))))

(defun $df_table_names (tbl)
  "Column names: df_table_names(T) => [\"x\", \"y\"]"
  (let ((t-struct (df-table-unwrap tbl)))
    `((mlist simp) ,@(dataframes:table-column-names t-struct))))

(defun $df_table_head (tbl &optional (n 5))
  "First n rows as a new table: df_table_head(T, n)"
  (let* ((t-struct (df-table-unwrap tbl))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (actual-n (min n (dataframes:table-nrows t-struct)))
         (new-cols
           (loop for col in cols
                 collect (etypecase col
                           (numerics:ndarray
                            (let* ((tensor (numerics:ndarray-tensor col))
                                   (dtype (numerics:ndarray-dtype col))
                                   (eltype (ecase dtype
                                             (:double-float 'double-float)
                                             (:complex-double-float '(complex double-float))))
                                   (result (magicl:empty (list actual-n)
                                                         :type eltype)))
                              (dotimes (i actual-n)
                                (setf (magicl:tref result i) (magicl:tref tensor i)))
                              (numerics:make-ndarray result :dtype dtype)))
                           (dataframes:string-column
                            (let ((data (dataframes:string-column-data col)))
                              (dataframes:make-string-column
                               (subseq data 0 actual-n))))))))
    (df-table-wrap (dataframes:make-table names new-cols))))
