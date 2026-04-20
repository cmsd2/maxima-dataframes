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

(defun tex-escape (s)
  "Escape a string for LaTeX \\text{}."
  (with-output-to-string (out)
    (loop for ch across s
          do (case ch
               (#\_ (write-string "\\_" out))
               (#\& (write-string "\\&" out))
               (#\% (write-string "\\%" out))
               (#\# (write-string "\\#" out))
               (#\{ (write-string "\\{" out))
               (#\} (write-string "\\}" out))
               (t   (write-char ch out))))))

(defun tex-string-column (x l r)
  (let ((sc (cadr x)))
    (if (typep sc 'dataframes:string-column)
        (let* ((n (dataframes:string-column-length sc))
               (data (dataframes:string-column-data sc))
               (show-n (min n 8))
               (items (loop for i below show-n
                            collect (format nil "\\text{~A}" (tex-escape (aref data i)))))
               (suffix (if (> n show-n)
                           (format nil ",\\; \\ldots\\; (\\text{~D total})" n)
                           "")))
          (append l
                  (list (format nil "\\left[~{~A~^,\\; ~}~A\\right]"
                                items suffix))
                  r))
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

(defun tex-format-cell (col row)
  "Format a single cell value for LaTeX display."
  (etypecase col
    (numerics:ndarray
     (let ((val (magicl:tref (numerics:ndarray-tensor col) row)))
       (if (complexp val)
           (let ((re (realpart val))
                 (im (imagpart val)))
             (cond
               ((zerop im) (format nil "~,4G" re))
               ((zerop re) (format nil "~,4Gi" im))
               ((plusp im) (format nil "~,4G+~,4Gi" re im))
               (t (format nil "~,4G~,4Gi" re im))))
           (format nil "~,4G" (realpart val)))))
    (dataframes:string-column
     (format nil "\\text{~A}" (tex-escape (aref (dataframes:string-column-data col) row))))))

(defun tex-df-table (x l r)
  "Render a table as a LaTeX array with headers, types, and data rows.
   Long tables show first 5 and last 2 rows with ellipsis."
  (let ((tbl (cadr x)))
    (if (typep tbl 'dataframes:table)
        (let* ((names (dataframes:table-column-names tbl))
               (cols (dataframes:table-columns tbl))
               (nrows (dataframes:table-nrows tbl))
               (ncols (length cols))
               (max-head 10)
               (max-tail 3)
               (truncate-p (> nrows (+ max-head max-tail)))
               ;; Column alignment spec: left-align all columns
               (col-spec (make-string ncols :initial-element #\l))
               ;; Header row: column names
               (header-cells
                 (mapcar (lambda (name)
                           (format nil "\\textbf{~A}" (tex-escape name)))
                         names))
               ;; Type row: dtype labels
               (type-cells
                 (mapcar (lambda (col)
                           (format nil "\\textit{~A}" (column-type-label col)))
                         cols))
               ;; Data rows to show
               (head-n (if truncate-p max-head nrows))
               (head-rows
                 (loop for i below head-n
                       collect (mapcar (lambda (col) (tex-format-cell col i)) cols)))
               (tail-rows
                 (when truncate-p
                   (loop for i from (- nrows max-tail) below nrows
                         collect (mapcar (lambda (col) (tex-format-cell col i)) cols))))
               ;; Ellipsis row
               (ellipsis-row
                 (when truncate-p
                   (make-list ncols :initial-element "\\cdots")))
               ;; Assemble all rows
               (all-data-rows
                 (if truncate-p
                     (append head-rows (list ellipsis-row) tail-rows)
                     head-rows))
               ;; Format each row as "cell & cell & ... \\\\"
               (row-strings
                 (mapcar (lambda (cells)
                           (format nil "~{~A~^ & ~} \\\\\\\\" cells))
                         all-data-rows))
               ;; Footer
               (footer (format nil "\\text{~D rows} \\times \\text{~D cols}" nrows ncols)))
          (append l
                  (list
                   (format nil
                           "\\begin{array}{~A} ~
                            ~{~A~^ & ~} \\\\\\\\ ~
                            ~{~A~^ & ~} \\\\\\\\ ~
                            \\hline ~
                            ~{~A~^ ~} ~
                            \\hline ~
                            ~A ~
                            \\end{array}"
                           col-spec
                           header-cells
                           type-cells
                           row-strings
                           footer))
                  r))
        (append l (list "\\text{df\\_table}(\\ldots)") r))))
