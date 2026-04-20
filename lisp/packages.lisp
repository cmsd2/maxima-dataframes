;;; packages.lisp — CL package definitions for dataframes

(defpackage #:dataframes
  (:use #:cl)
  (:export
   ;; String column
   #:string-column
   #:string-column-p
   #:make-string-column
   #:string-column-data
   #:string-column-length
   ;; Table
   #:table
   #:table-p
   #:%make-table
   #:make-table
   #:table-column-names
   #:table-columns
   #:table-nrows
   ;; Grouped table
   #:grouped-table
   #:grouped-table-p
   #:%make-grouped-table
   #:grouped-table-table
   #:grouped-table-group-column
   #:grouped-table-group-keys
   #:grouped-table-group-indices))
