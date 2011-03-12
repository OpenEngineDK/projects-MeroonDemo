
(define-class Transformation Object
  ([= translation 
      :initializer (lambda () (make-vector 3 0.0))]
   [= scaling
      :initializer (lambda () (make-vector 3 1.0))]
   [= rotation
      :initializer (lambda () (make-quaternion))]))

;;; methods

(define-generic (Transformation-translate (o Transformation) x y z)
  (with-access o (Transformation translation)
    (set! translation (vector-map + translation (vector x y z)))))

(define-generic (Transformation-scale (o Transformation) x y z)
  (with-access o (Transformation scaling)
    (set! scaling (vector-map * scaling (vector x y z)))))

(define-generic (Transformation-rotate (o Transformation) x y z)
  (with-access o (Transformation rotation)
    (set! rotation (quaternion* rotation (make-quaternion x y z)))))

(define-method (show (o Transformation) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (with-access o (Transformation translation scaling rotation)
      (display "#<a Transformation: translation(" stream)
      (show translation stream)
      (display ") scaling(" stream)
      (show scaling stream)
      (display ") rotation(" stream)
      (show rotation stream)
      (display ")>" stream))))
