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
      :initializer (lambda () (instantiate Quaternion))]
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


(define (update-transformation-rot-and-scl! o)
  (let ([scl (Transformation-scaling o)])
    ((c-lambda (float float float FloatArray FloatArray) void
#<<UPDATE_TRANSFORMATION_ROT_AND_SCL_END
float x      = ___arg1;
float y      = ___arg2;
float z      = ___arg3;
float* m_rot = ___arg4;
float* m     = ___arg5;

// first column
m[0] = m_rot[0] * x;
m[1] = m_rot[1];
m[2] = m_rot[2];

// second column
m[4] = m_rot[3];
m[5] = m_rot[4] * y;
m[6] = m_rot[5];

// third column
m[8]  = m_rot[6];
m[9]  = m_rot[7];
m[10] = m_rot[8] * z;

UPDATE_TRANSFORMATION_ROT_AND_SCL_END
  )
   (vector-ref scl 0)
   (vector-ref scl 1)
   (vector-ref scl 2)
   (Quaternion-c-matrix (Transformation-rotation o))
   (Transformation-c-matrix o))))


;;; methods

(define-generic (Transformation-translate (o Transformation) x y z)
  (with-access o (Transformation translation)
    (set! translation (vector-map + translation (vector x y z)))))

(define-generic (Transformation-scale (o Transformation) x y z)
  (with-access o (Transformation scaling)
    (set! scaling (vector-map * scaling (vector x y z)))))

(define-generic (Transformation-rotate (o Transformation) angle vec)
  (with-access o (Transformation rotation)
    (set! rotation (quaternion* rotation (mk-Quaternion angle vec)))
    (update-c-matrix! rotation)))

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
