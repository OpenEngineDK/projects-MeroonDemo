(define make-modules list)

(define add-module cons)

(define (process-modules ms) 
  (map (lambda (f) (f)) ms))

(define (make-rotator rotatable delta-angle axis)
  (lambda () 
    (rotate! rotatable delta-angle axis)))
