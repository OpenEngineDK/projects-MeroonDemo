
;; Top type for contexts
(define-class Context Object ())

;; Generic rendering function
(define-generic (render! (ctx Context) (can Canvas)))

(define-generic (initialize-context! (ctx Context)))