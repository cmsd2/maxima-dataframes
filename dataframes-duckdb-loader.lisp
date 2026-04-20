;;; dataframes-duckdb-loader.lisp — Bootstrap DuckDB integration

(in-package :maxima)

;; Bootstrap Quicklisp if available but not loaded
(unless (find-package :quicklisp)
  (let ((ql-init (merge-pathnames "quicklisp/setup.lisp"
                                  (user-homedir-pathname))))
    (if (probe-file ql-init)
        (load ql-init)
        (error "Quicklisp not found. Install it:~%~
                curl -O https://beta.quicklisp.org/quicklisp.lisp~%~
                sbcl --load quicklisp.lisp ~
                --eval '(quicklisp-quicklisp:install)' --quit"))))

;; Register paths (idempotent)
(let* ((here (make-pathname :directory (pathname-directory *load-truename*))))
  (pushnew here asdf:*central-registry* :test #'equal)
  (pushnew (merge-pathnames "lisp/" here)
           asdf:*central-registry* :test #'equal))

;; Load the DuckDB extension system via Quicklisp
(funcall (intern "QUICKLOAD" :ql) "dataframes-duckdb" :silent t)

;; Load doc index for ? and ?? help (if available)
(let* ((here (make-pathname :directory (pathname-directory *load-truename*)))
       (idx (merge-pathnames "dataframes-duckdb-index.lisp" here)))
  (when (probe-file idx)
    ($load (namestring idx))))
