#!gsc-script

(include "gsc-parse.scm")

(call-with-values (lambda () (parse (cdr (command-line))))
  (lambda (target link loads incs files enabled disabled)
    ;;(pp (list target link loads incs files enabled disabled))
    ;;(newline)    
    (for-each (lambda (f) (eval `(include ,f))) incs)
    (for-each (lambda (f) (load f)) loads)
    (for-each (lambda (f) (compile-file-to-c f)) files)
    (link-flat (files->modules files) output: target warnings?: #f)))
