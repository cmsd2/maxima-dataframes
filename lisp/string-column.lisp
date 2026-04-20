;;; string-column.lisp — A 1D column of strings

(in-package #:dataframes)

(defstruct (string-column
            (:constructor %make-string-column)
            (:print-function print-string-column))
  "A 1D column of strings, backed by a CL simple-vector."
  (data #() :type simple-vector)
  (length 0 :type fixnum))

(defun print-string-column (obj stream depth)
  (declare (ignore depth))
  (format stream "#<string-column ~D>" (string-column-length obj)))

(defun make-string-column (strings)
  "Create a string-column from a CL vector of strings."
  (let ((vec (if (typep strings 'simple-vector)
                 strings
                 (coerce strings 'simple-vector))))
    (%make-string-column :data vec :length (length vec))))

;;; Maxima-level helpers

(in-package #:maxima)

(defun $string_column_p (x)
  "Predicate: is X a string-column handle?"
  (and (listp x)
       (listp (car x))
       (eq (caar x) '$string_column)
       (typep (cadr x) 'dataframes:string-column)))

(defun string-column-unwrap (x)
  "Extract the Lisp string-column struct from a Maxima expression."
  (unless ($string_column_p x)
    (merror "Expected a string_column, got: ~M" x))
  (cadr x))

(defun string-column-wrap (sc)
  "Wrap a Lisp string-column struct into a Maxima expression."
  `(($string_column simp) ,sc))

(defun $df_string_column (lst)
  "Create a string-column from a Maxima list of strings.
   df_string_column([\"a\", \"b\", \"c\"])"
  (unless ($listp lst)
    (merror "df_string_column: expected a list, got: ~M" lst))
  (let* ((items (cdr lst))
         (strings (map 'simple-vector
                       (lambda (x) ($sconcat x))
                       items)))
    (string-column-wrap (dataframes:make-string-column strings))))

(defun $df_to_string_list (col)
  "Convert a string-column to a Maxima list of strings.
   df_to_string_list(sc) => [\"a\", \"b\", \"c\"]"
  (let* ((sc (string-column-unwrap col))
         (data (dataframes:string-column-data sc)))
    `((mlist simp) ,@(coerce data 'list))))

(defun $df_string_column_p (x)
  "Predicate: is X a string-column?
   df_string_column_p(sc) => true/false"
  (if ($string_column_p x) t nil))

(defun $df_string_column_ref (col i)
  "Access element i (1-indexed) of a string-column.
   df_string_column_ref(sc, 1) => \"a\""
  (let* ((sc (string-column-unwrap col))
         (data (dataframes:string-column-data sc))
         (len (dataframes:string-column-length sc)))
    (unless (and (integerp i) (>= i 1) (<= i len))
      (merror "df_string_column_ref: index ~M out of bounds [1, ~M]" i len))
    (aref data (1- i))))

(defun $df_string_column_length (col)
  "Length of a string-column.
   df_string_column_length(sc) => 3"
  (let ((sc (string-column-unwrap col)))
    (dataframes:string-column-length sc)))
