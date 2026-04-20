;;; convert.lisp — cl-duckdb result alist → df_table conversion

(in-package #:maxima)

;;; cl-duckdb returns query results as alists:
;;;   (("col1" . #(v1 v2 ...)) ("col2" . #(v1 v2 ...)) ...)
;;;
;;; Vector types observed:
;;;   DOUBLE     → (simple-array double-float (*))
;;;   INTEGER    → (simple-array (signed-byte 32) (*))
;;;   BIGINT     → (simple-array (signed-byte 64) (*))
;;;   VARCHAR    → simple-vector of strings
;;;   with NULLs → simple-vector with NIL elements
;;;   BOOLEAN    → simple-vector with T/NIL
;;;   DECIMAL    → simple-vector with rationals

(defun df-duckdb-classify-vector (vec)
  "Classify a cl-duckdb result vector by its element type.
   Returns :double, :integer, :string, or :mixed."
  (let ((eltype (array-element-type vec)))
    (cond
      ;; Specialized double-float array
      ((subtypep eltype 'double-float) :double)
      ;; Specialized integer arrays (signed-byte 32, 64, etc.)
      ((subtypep eltype 'integer) :integer)
      ;; General simple-vector: inspect elements
      ((eq eltype t)
       (if (zerop (length vec))
           :string
           (let ((first-non-nil (find-if #'identity vec)))
             (cond
               ((null first-non-nil) :double)       ; all-nil → numeric
               ((numberp first-non-nil) :mixed)     ; rationals, booleans, etc.
               ((stringp first-non-nil) :string)
               (t :string)))))                       ; fallback
      (t :string))))

(defun df-duckdb-vec-to-ndarray (vec)
  "Convert a cl-duckdb numeric vector to an ndarray.
   Handles double-float arrays, integer arrays, and mixed simple-vectors
   containing numbers or NIL. NIL values become NaN."
  (let* ((n (length vec))
         (nan (sb-kernel:make-double-float
               (ash #x7FF80000 -32)    ; quiet NaN high word
               0))                     ; low word
         (tensor (magicl:empty (list n) :type 'double-float
                                        :layout :column-major)))
    (dotimes (i n)
      (let ((v (aref vec i)))
        (setf (magicl:tref tensor i)
              (cond
                ((null v) nan)
                ((typep v 'double-float) v)
                ((numberp v) (coerce (rational v) 'double-float))
                (t nan)))))
    (numerics:make-ndarray tensor)))

(defun df-duckdb-vec-to-string-column (vec)
  "Convert a cl-duckdb string vector to a string-column.
   NIL values become empty strings."
  (let* ((n (length vec))
         (data (make-array n)))
    (dotimes (i n)
      (let ((v (aref vec i)))
        (setf (aref data i) (if v (princ-to-string v) ""))))
    (dataframes:make-string-column data)))

(defun df-duckdb-result-to-table (result)
  "Convert a cl-duckdb result alist to a df_table.
   Each pair in RESULT is (column-name-string . cl-vector).
   Type mapping:
     double-float arrays   → ndarray
     integer arrays         → ndarray (coerced to double)
     mixed vectors (nums)   → ndarray (coerced to double, NIL→NaN)
     string vectors         → string-column (NIL→empty string)"
  (when (null result)
    (return-from df-duckdb-result-to-table
      (dataframes::%make-table :column-names nil :columns nil :nrows 0)))
  (let ((names (mapcar #'car result))
        (columns
          (mapcar (lambda (pair)
                    (let* ((vec (cdr pair))
                           (kind (df-duckdb-classify-vector vec)))
                      (case kind
                        ((:double :integer :mixed)
                         (df-duckdb-vec-to-ndarray vec))
                        (t
                         (df-duckdb-vec-to-string-column vec)))))
                  result)))
    (dataframes:make-table names columns)))
