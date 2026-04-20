;;; describe.lisp — Column aggregation primitives and df_describe

(in-package #:maxima)

;;; ---- Column-level aggregation functions ----

(defun $df_count (col)
  "Count elements in a column (ndarray or string-column).
   df_count(col) => integer"
  (cond
    (($ndarray_p col)
     (let* ((h (numerics-unwrap col))
            (tensor (numerics:ndarray-tensor h)))
       (first (magicl:shape tensor))))
    (($string_column_p col)
     (dataframes:string-column-length (string-column-unwrap col)))
    (t (merror "df_count: expected ndarray or string_column, got: ~M" col))))

(defun df-sorted-values (tensor)
  "Extract values from a 1D tensor as a sorted double-float array."
  (let* ((n (first (magicl:shape tensor)))
         (arr (make-array n :element-type 'double-float)))
    (dotimes (i n)
      (setf (aref arr i) (coerce (realpart (magicl:tref tensor i)) 'double-float)))
    (sort arr #'<)))

(defun $df_median (col)
  "Median of a 1D ndarray.
   df_median(col) => number"
  (numerics-require-real col "df_median")
  (let* ((h (numerics-unwrap col))
         (tensor (numerics:ndarray-tensor h))
         (sorted (df-sorted-values tensor))
         (n (length sorted)))
    (when (zerop n)
      (merror "df_median: empty array"))
    (if (oddp n)
        (aref sorted (floor n 2))
        (/ (+ (aref sorted (1- (floor n 2)))
              (aref sorted (floor n 2)))
           2.0d0))))

(defun df-quantile-sorted (sorted p)
  "Compute p-quantile from a pre-sorted array using linear interpolation."
  (let* ((n (length sorted))
         (index (* p (1- n)))
         (lo (floor index))
         (hi (ceiling index))
         (frac (- index lo)))
    (if (= lo hi)
        (aref sorted lo)
        (+ (* (aref sorted lo) (- 1.0d0 frac))
           (* (aref sorted hi) frac)))))

(defun $df_quantile (col p)
  "p-quantile (0 to 1) of a 1D ndarray, using linear interpolation.
   df_quantile(col, 0.25) => number"
  (numerics-require-real col "df_quantile")
  (let* ((p-val ($float p))
         (h (numerics-unwrap col))
         (tensor (numerics:ndarray-tensor h))
         (sorted (df-sorted-values tensor))
         (n (length sorted)))
    (when (zerop n)
      (merror "df_quantile: empty array"))
    (unless (and (>= p-val 0.0d0) (<= p-val 1.0d0))
      (merror "df_quantile: p must be between 0 and 1, got: ~M" p))
    (df-quantile-sorted sorted p-val)))

(defun $df_unique (col)
  "Unique values of a string-column, returned as a new string-column.
   df_unique(col) => string_column"
  (let* ((sc (string-column-unwrap col))
         (data (dataframes:string-column-data sc))
         (seen (make-hash-table :test #'equal))
         (uniq '()))
    (loop for s across data
          do (unless (gethash s seen)
               (setf (gethash s seen) t)
               (push s uniq)))
    (string-column-wrap
     (dataframes:make-string-column
      (coerce (nreverse uniq) 'simple-vector)))))

(defun $df_nunique (col)
  "Count of unique values in a column (ndarray or string-column).
   df_nunique(col) => integer"
  (cond
    (($string_column_p col)
     (let* ((sc (string-column-unwrap col))
            (data (dataframes:string-column-data sc))
            (seen (make-hash-table :test #'equal)))
       (loop for s across data do (setf (gethash s seen) t))
       (hash-table-count seen)))
    (($ndarray_p col)
     (let* ((h (numerics-unwrap col))
            (tensor (numerics:ndarray-tensor h))
            (n (first (magicl:shape tensor)))
            (seen (make-hash-table :test #'eql)))
       (dotimes (i n)
         (setf (gethash (magicl:tref tensor i) seen) t))
       (hash-table-count seen)))
    (t (merror "df_nunique: expected ndarray or string_column, got: ~M" col))))

(defun $df_value_counts (col)
  "Frequency table for a column, returned as a df_table with columns [\"value\", \"count\"].
   Sorted by count descending. Works on string-columns and ndarrays.
   df_value_counts(col) => df_table"
  (let ((counts (make-hash-table :test #'equal))
        (keys '()))
    ;; Count occurrences
    (cond
      (($string_column_p col)
       (let* ((sc (string-column-unwrap col))
              (data (dataframes:string-column-data sc)))
         (loop for s across data
               do (unless (gethash s counts)
                    (push s keys))
                  (incf (gethash s counts 0)))))
      (($ndarray_p col)
       (let* ((h (numerics-unwrap col))
              (tensor (numerics:ndarray-tensor h))
              (n (first (magicl:shape tensor))))
         (dotimes (i n)
           (let ((v (magicl:tref tensor i)))
             (unless (gethash v counts)
               (push (format nil "~A" v) keys))
             (incf (gethash v counts 0))))))
      (t (merror "df_value_counts: expected ndarray or string_column, got: ~M" col)))
    ;; Sort by count descending
    (let* ((sorted-keys (sort (nreverse keys)
                              (lambda (a b)
                                (> (gethash a counts) (gethash b counts)))))
           (n (length sorted-keys))
           (value-vec (coerce sorted-keys 'simple-vector))
           (count-tensor (magicl:empty (list n) :type 'double-float
                                                :layout :column-major)))
      (loop for k in sorted-keys
            for i from 0
            do (setf (magicl:tref count-tensor i)
                     (coerce (gethash k counts) 'double-float)))
      (df-table-wrap
       (dataframes:make-table
        (list "value" "count")
        (list (dataframes:make-string-column value-vec)
              (numerics:make-ndarray count-tensor)))))))

;;; ---- df_describe ----

(defun df-column-std1 (tensor n)
  "Sample standard deviation (n-1 denominator) of a 1D tensor."
  (if (<= n 1)
      0.0d0
      (let ((mean 0.0d0)
            (sum-sq 0.0d0))
        (dotimes (i n)
          (incf mean (coerce (realpart (magicl:tref tensor i)) 'double-float)))
        (setf mean (/ mean (coerce n 'double-float)))
        (dotimes (i n)
          (let ((d (- (coerce (realpart (magicl:tref tensor i)) 'double-float) mean)))
            (incf sum-sq (* d d))))
        (sqrt (/ sum-sq (coerce (1- n) 'double-float))))))

(defun $df_describe (tbl)
  "Summary statistics for numeric columns of a table.
   Returns a df_table with rows [count, mean, std, min, 25%, 50%, 75%, max]
   and one column per numeric input column, plus a 'stat' string-column.
   df_describe(T) => df_table"
  (let* ((t-struct (df-table-unwrap tbl))
         (names (dataframes:table-column-names t-struct))
         (cols (dataframes:table-columns t-struct))
         (stat-labels #("count" "mean" "std" "min" "25%" "50%" "75%" "max"))
         (nstats (length stat-labels))
         ;; Filter to numeric columns
         (num-pairs (loop for name in names
                          for col in cols
                          when (typep col 'numerics:ndarray)
                          collect (cons name col)))
         (result-names (list "stat"))
         (result-cols (list (dataframes:make-string-column stat-labels))))
    (when (null num-pairs)
      (merror "df_describe: table has no numeric columns"))
    (dolist (pair num-pairs)
      (let* ((name (car pair))
             (col (cdr pair))
             (tensor (numerics:ndarray-tensor col))
             (n (first (magicl:shape tensor)))
             (sorted (df-sorted-values tensor))
             ;; Compute stats
             (count-val (coerce n 'double-float))
             (mean-val (let ((s 0.0d0))
                         (dotimes (i n) (incf s (aref sorted i)))
                         (/ s count-val)))
             (std-val (df-column-std1 tensor n))
             (min-val (aref sorted 0))
             (q25-val (df-quantile-sorted sorted 0.25d0))
             (q50-val (df-quantile-sorted sorted 0.50d0))
             (q75-val (df-quantile-sorted sorted 0.75d0))
             (max-val (aref sorted (1- n)))
             ;; Build result column
             (result-tensor (magicl:empty (list nstats) :type 'double-float
                                                        :layout :column-major)))
        (setf (magicl:tref result-tensor 0) count-val)
        (setf (magicl:tref result-tensor 1) mean-val)
        (setf (magicl:tref result-tensor 2) std-val)
        (setf (magicl:tref result-tensor 3) min-val)
        (setf (magicl:tref result-tensor 4) q25-val)
        (setf (magicl:tref result-tensor 5) q50-val)
        (setf (magicl:tref result-tensor 6) q75-val)
        (setf (magicl:tref result-tensor 7) max-val)
        (push name result-names)
        (push (numerics:make-ndarray result-tensor) result-cols)))
    (df-table-wrap
     (dataframes:make-table
      (nreverse result-names)
      (nreverse result-cols)))))
