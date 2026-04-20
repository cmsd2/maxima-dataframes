;;; dataframes-loader.lisp — Bootstrap Quicklisp and load the dataframes ASDF system
;;; This file is loaded as Common Lisp from dataframes.mac via load().

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

;; Derive the project directory from this file's location and register paths
(let* ((here (make-pathname :directory (pathname-directory *load-truename*))))
  (pushnew here asdf:*central-registry* :test #'equal)
  (pushnew (merge-pathnames "lisp/" here)
           asdf:*central-registry* :test #'equal))

;; Load the dataframes system via Quicklisp (resolves dependencies)
(funcall (intern "QUICKLOAD" :ql) "dataframes" :silent t)

;; Load doc index for ? and ?? help (if available)
(let* ((here (make-pathname :directory (pathname-directory *load-truename*)))
       (idx (merge-pathnames "dataframes-index.lisp" here)))
  (when (probe-file idx)
    ($load (namestring idx))))
