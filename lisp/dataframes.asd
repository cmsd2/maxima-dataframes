;;; dataframes.asd — ASDF system definition for dataframes

(defsystem "dataframes"
  :description "Pandas-like tabular data for Maxima"
  :version "0.1.0"
  :license "MIT"
  :depends-on ("alexandria")
  :serial t
  :components
  ((:file "packages")
   (:file "string-column")
   (:file "table")
   (:file "describe")
   (:file "display")))
