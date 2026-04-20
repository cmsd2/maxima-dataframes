;;; display.lisp — Custom Maxima display for string-column and df_table

(in-package #:maxima)

;;; String-column display

(displa-def $string_column dim-$string_column)

(defun dim-$string_column (form result)
  "Display a string-column: string_column(3) [\"a\", \"b\", \"c\"]"
  (let ((sc (cadr form)))
    (if (typep sc 'dataframes:string-column)
        (let* ((n (dataframes:string-column-length sc))
               (data (dataframes:string-column-data sc))
               (preview-n (min n 6))
               (items (loop for i below preview-n
                            collect (format nil "~S" (aref data i))))
               (suffix (if (> n preview-n) ", ..." ""))
               (body (format nil "[~{~A~^, ~}~A]" items suffix)))
          (dimension-function
           `((mprogn) ,(format nil "string_column(~D) ~A" n body))
           result))
        (dimension-function form result))))

(defprop $string_column tex-string-column tex)

(defun tex-string-column (x l r)
  (let ((sc (cadr x)))
    (if (typep sc 'dataframes:string-column)
        (append l
                (list (format nil "\\text{string\\_column}(~D)"
                              (dataframes:string-column-length sc)))
                r)
        (append l (list "\\text{string\\_column}(\\ldots)") r))))

;;; Table display

(displa-def $df_table dim-$df_table)

(defun format-column-value (col row)
  "Format a single cell value for display."
  (etypecase col
    (numerics:ndarray
     (let ((val (magicl:tref (numerics:ndarray-tensor col) row)))
       (format nil "~,4G" (realpart val))))
    (dataframes:string-column
     (format nil "~S" (aref (dataframes:string-column-data col) row)))))

(defun column-type-label (col)
  "Short type label for a column."
  (etypecase col
    (numerics:ndarray
     (ecase (numerics:ndarray-dtype col)
       (:double-float "f64")
       (:complex-double-float "c128")))
    (dataframes:string-column "str")))

(defun dim-$df_table (form result)
  "Display a table with column names, types, and first few rows."
  (let ((tbl (cadr form)))
    (if (typep tbl 'dataframes:table)
        (let* ((names (dataframes:table-column-names tbl))
               (cols (dataframes:table-columns tbl))
               (nrows (dataframes:table-nrows tbl))
               (ncols (length cols))
               (show-n (min nrows 5))
               (header (format nil "df_table: ~D rows x ~D cols" nrows ncols))
               (col-headers (format nil "  ~{~A~^ | ~}"
                                    (mapcar (lambda (name col)
                                              (format nil "~A (~A)" name (column-type-label col)))
                                            names cols)))
               (rows (loop for i below show-n
                           collect (format nil "  ~{~A~^ | ~}"
                                           (mapcar (lambda (col)
                                                     (format-column-value col i))
                                                   cols))))
               (footer (when (> nrows show-n)
                         (format nil "  ... (~D more rows)" (- nrows show-n))))
               (lines (remove nil
                              (append (list header col-headers) rows (list footer)))))
          (dimension-function
           `((mprogn) ,(format nil "~{~A~^~%~}" lines))
           result))
        (dimension-function form result))))

(defprop $df_table tex-df-table tex)

(defun tex-df-table (x l r)
  (let ((tbl (cadr x)))
    (if (typep tbl 'dataframes:table)
        (let ((nrows (dataframes:table-nrows tbl))
              (ncols (length (dataframes:table-columns tbl))))
          (append l
                  (list (format nil "\\text{df\\_table}(~D \\times ~D)" nrows ncols))
                  r))
        (append l (list "\\text{df\\_table}(\\ldots)") r))))
