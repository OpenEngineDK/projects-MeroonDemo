(define-class Transformation Object
  ([= translation 
      :initializer (lambda () (make-vector 3 0.0))]
   [= scaling
      :initializer (lambda () (make-vector 3 1.0))]
   [= rotation
      :initializer (lambda () (make-quaternion))]))

;; move, scale, rotate

(define (transformation-translate o x y z)
  (with-access o (Transformation translation)
     (set! translation (vector-map + translation (vector x y z)))))

(define (transformation-scale o x y z)
  (with-access o (Transformation scaling)
     (set! scaling (vector-map * scaling (vector x y z)))))

(define (transformation-rotate o x y z)
  (with-access o (Transformation rotation)
     (set! rotation (quaternion* rotation (make-quaternion x y z)))))
