(c-declare #<<c-declare-end
#include <cstring>
c-declare-end
)

(c-define-type FloatArray (pointer "float"))

(define-class Transformation Object
  ([= translation 
      :initializer (lambda () (make-vector 3 0.0))]
   [= scaling
      :initializer (lambda () (make-vector 3 1.0))]
   [= rotation
      :initializer (lambda () (make-quaternion))]
   [= c-matrix :immutable 
      :initializer (c-lambda () FloatArray
		     "float* m = new float[16];
                     memset(m, 0x0, sizeof(float) * 16); 
                     m[0]  = 1.0f;
                     m[5]  = 1.0f;
                     m[10] = 1.0f;
                     m[15] = 1.0f;
		     ___result_voidstar = m;"
		     )]))

(define (update-transformation-pos! o)
  (let ([pos (Transformation-translation o)])
    ((c-lambda (float float float FloatArray) void
#<<UPDATE_TRANSFORMATION_POS_END
float x  = ___arg1;
float y  = ___arg2;
float z  = ___arg3;
float* m = ___arg4;

// fourth column
m[12] = -x;
m[13] = -y;
m[14] = -z;
UPDATE_TRANSFORMATION_POS_END
  )
   (vector-ref pos 0)
   (vector-ref pos 1)
   (vector-ref pos 2)
   (Transformation-c-matrix o))))


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
