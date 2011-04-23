;; This module provides methods on inexact numeric vectors.  An engine
;; vector is a vector of 32-bit floats and we simply use Gambit's
;; f32vector as the internal representation.

;; Standard vector operations
(define vec? f32vector?)
(define make-vec make-f32vector)
(define vec f32vector)
;; (define (vec . args)
;;   (apply f32vector (map exact->inexact args)))
(define vec-length f32vector-length)
(define vec-ref f32vector-ref)
(define vec-set! f32vector-set!)
(define vec->list f32vector->list)
(define list->vec list->f32vector)
(define vec-fill! f32vector-fill!)
(define subvec-fill! subf32vector-fill!)
(define append-vecs append-f32vectors)
(define vec-copy f32vector-copy)
(define vec-append f32vector-append)
(define subvec subf32vector)
(define subvec-move! subf32vector-move!)
(define vec-shrink! f32vector-shrink!)

;; procedure: (vec-map procedure vec1 vec2 ...)
;; returns: vec of results
;;
;; 'vec-map' is analogous to the 'map' procedure on lists.
;;
;; The native 'vector-map' is part of R6RS:
;;  http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-14.html#node_idx_742
;;
;; vec-map applies procedure element-wise to vec1 vec2 ...
;; and returns a new vector with the resulting values. The vectors
;; must be of the same length. The procedure should accept as many
;; arguments as there are vectors and should return a single value.
;;
;; Note: the behavior of multiple returns is unknown (not as R6RS).
;;
;; Examples:
;;
;; > (vec-map abs (vec 1 -2 3 -4))
;; #(1 2 3 4)
;;
;; > (vec-map + (vec 1 2 3) (vec 4 5 6))
;; #(5 7 9)
;;
;; > (vec-map (lambda (x y) (* x y))
;;               (vec 1 2 3)
;;               (vec 4 5 6))
;; #(4 10 18)
;;
(define (vec-map f vec . vecs)
  (let* ([len (vec-length vec)]
         [num (length vecs)]
         [res (make-vec len)])
    (cond
      ;; fast path: mapping over one vector
      [(fx= 0 num)
       (do ([i 0 (fx+ 1 i)])
           ((fx= i len) res)
         (vec-set! res i (f (vec-ref vec i))))]
      ;; fast path: mapping over two vectors
      [(fx= 1 num)
       (let ([vec2 (car vecs)])
         (if (not (fx= len (vec-length vec2)))
             (error "(Argument 3) Vector is not of proper length")
             (do ([i 0 (fx+ 1 i)])
                 ((fx= i len) res)
               (vec-set! res i (f (vec-ref vec i) 
                                  (vec-ref vec2 i))))))]
      ;; general case: mapping over n vectors
      [else
       ;; check that all vectors have length equal to the first
       (do ([argi 3 (fx+ 1 argi)] [vecs vecs (cdr vecs)])
           ((null? vecs))
         (if (not (fx= len (vec-length (car vecs))))
             (error (string-append "(Argument " (number->string argi)
                                   ") Vector is not of proper length"))))
       ;; args builds a reversed list of the i'th args
       (letrec ([args (lambda (i vs is)
                        (if (null? vs) is
                            (args i (cdr vs)
                                  (cons (vec-ref (car vs) i) is))))])
         ;; rvecs is the reversed list of vectors
         (let ([rvecs (reverse (cons vec vecs))])
           (do ([i 0 (fx+ 1 i)])
               ((fx= i len) res)
             (vec-set! res i (apply f (args i rvecs '()))))))])))

(define (vec-deref v f)
  (apply f (vec->list v)))

(define (vec-dot v1 v2)
  (apply fl+ (vec->list (vec-map fl* v1 v2))))

(define (vec-norm v)
  (flsqrt (vec-dot v v)))

(define (vec-normalize v)
  (let ([normv (make-vec (vec-length v) (vec-norm v))])
    (vec-map fl/ v normv)))

(define (vec+ . vecs)
  (apply vec-map (cons fl+ vecs)))

(define (vec- . vecs)
  (apply vec-map (cons fl- vecs)))

(define (vec-scalar* s v)
  (vec-map (lambda (e) (fl* s e)) v))

(define (vec-cross v1 v2)
  (if (not (and (fx= 3 (vec-length v1))
                (fx= 3 (vec-length v2))))
      (error "The cross produce is only defined on vectors of length 3")
      (f32vector (fl- (fl* (vec-ref v1 1) (vec-ref v2 2))
                      (fl* (vec-ref v1 2) (vec-ref v2 1)))
                 (fl- (fl* (vec-ref v1 2) (vec-ref v2 0))
                      (fl* (vec-ref v1 0) (vec-ref v2 2)))
                 (fl- (fl* (vec-ref v1 0) (vec-ref v2 1))
                      (fl* (vec-ref v1 1) (vec-ref v2 0))))))

(define (vec-interp v1 v2 scale)
  (vec+ v1 (vec-scalar* scale (vec- v2 v1))))

(define (vector->vec v)
  ;; Assumes that *v* is a vector of numbers.
  (let* ([len (vector-length v)]
         [fv (make-vec len)])
    (do ([i 0 (fx+ i 1)])
        ((fx= i len) fv)
      (vec-set! fv i (exact->inexact (vector-ref v i))))))

(define (vec->vector v)
  (list->vector (vec->list v)))
