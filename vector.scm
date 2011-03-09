;; procedure: (vector-map procedure vector1 vector2 ...)
;; returns: vector of results
;;
;; 'vector-map' is a mirror of the primitive 'map' procedure on lists.
;;
;; vector-map applies procedure to elements of vector1 vector2 ... and
;; returns a new vector with the resulting values. The vectors must be
;; of the same length. The procedure should accept as many arguments
;; as there are vectors and should return a single value.
;;
;; Examples:
;;
;; > (vector-map abs (vector 1 -2 3 -4))
;; #(1 2 3 4)
;;
;; > (vector-map + (vector 1 2 3) (vector 4 5 6))
;; #(5 7 9)
;;
;; > (vector-map (lambda (x y) (* x y))
;;               (vector 1 2 3)
;;               (vector 4 5 6))
;; #(4 10 18)
;;
(define (vector-map f vec . vecs)
  (let* ([len (vector-length vec)]
         [num (length vecs)]
         [res (make-vector len)])
    (cond
      ;; fast path: mapping over one vector
      [(fx= 0 num)
       (do ([i 0 (fx+ 1 i)])
           ((fx= i len) res)
         (vector-set! res i (f (vector-ref vec i))))]
      ;; fast path: mapping over two vectors
      [(fx= 1 num)
       (let ([vec2 (car vecs)])
         (if (not (fx= len (vector-length vec2)))
             (error "(Argument 3) Vector is not of proper length")
             (do ([i 0 (fx+ 1 i)])
                 ((fx= i len) res)
               (vector-set! res i (f (vector-ref vec i) 
                                     (vector-ref vec2 i))))))]
      ;; general case: mapping over n vectors
      [else
       ;; check that all vectors have length equal to the first
       (do ([argi 3 (fx+ 1 argi)] [vecs vecs (cdr vecs)])
           ((null? vecs))
         (if (not (fx= len (vector-length (car vecs))))
             (error (string-append "(Argument " (number->string argi)
                                   ") Vector is not of proper length"))))
       ;; args builds a reversed list of the i'th args
       (letrec ([args (lambda (i vs is)
                        (if (null? vs) is
                            (args i (cdr vs)
                                  (cons (vector-ref (car vs) i) is))))])
         ;; rvecs is the reversed list of vectors
         (let ([rvecs (reverse (cons vec vecs))])
           (do ([i 0 (fx+ 1 i)])
               ((fx= i len) res)
             (vector-set! res i (apply f (args i rvecs '()))))))])))