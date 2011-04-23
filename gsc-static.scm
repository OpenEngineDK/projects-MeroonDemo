#!gsc-script

(include "gsc-parse.scm")

(call-with-values (lambda () (parse (cdr (command-line))))
  (lambda (target link loads incs files enabled disabled)
    ;;(pp (list link)) ;;target link loads incs files enabled disabled))
    ;;(newline)
    (for-each (lambda (f) (eval `(include ,f))) incs)
    (for-each (lambda (f) (load f)) loads)
    (for-each (lambda (f) (compile-file-to-c f)) files)
    (link-incremental (files->modules files) output: target base: link)))