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
   #:make-table
   #:table-column-names
   #:table-columns
   #:table-nrows))
