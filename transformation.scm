(c-declare #<<c-declare-end
#include <cstring>
#include <cstdio>
c-declare-end
)

(define-class Transformation Object
  ([= translation 
      :initializer (lambda () (make-vector 3 0.0))]
   [= scaling
      :initializer (lambda () (make-vector 3 1.0))]
   [= rotation
      :initializer (lambda () (instantiate Quaternion))]
   [= pivot :initializer (lambda () #f)]
   [= c-matrix :immutable 
      :initializer (c-lambda () (pointer float)
		     "float* m = new float[16];
                     memset(m, 0x0, sizeof(float) * 16); 
                     m[0]  = 1.0f;
                     m[5]  = 1.0f;
                     m[10] = 1.0f;
                     m[15] = 1.0f;
		     ___result_voidstar = m;"
		     )]))

(define-method (initialize! (o Transformation))
  ;; free the c-matrix when object is reclaimed by the gc.
  (update-transformation-rot-and-scl! o)
  (update-transformation-pos! o)
  (make-will o (lambda (x) 
		 (with-access x (Transformation c-matrix)
	           ((c-lambda ((pointer float)) void
		      "delete[] ___arg1;")
                    c-matrix))))
  (call-next-method))

(define c-update-transformation-pivot!
  (c-lambda (scheme-object scheme-object scheme-object (pointer float) (pointer float)) void
#<<UPDATE_TRANSFORMATION_PIVOT_END
// printf("pivot\n");

const ___SCMOBJ scm_x  = ___VECTORREF(___arg1, 0);
const ___SCMOBJ scm_y  = ___VECTORREF(___arg1, 4);
const ___SCMOBJ scm_z  = ___VECTORREF(___arg1, 8);
const ___SCMOBJ scm_px = ___VECTORREF(___arg2, 0);
const ___SCMOBJ scm_py = ___VECTORREF(___arg2, 4);
const ___SCMOBJ scm_pz = ___VECTORREF(___arg2, 8);
const ___SCMOBJ scm_sx = ___VECTORREF(___arg3, 0);
const ___SCMOBJ scm_sy = ___VECTORREF(___arg3, 4);
const ___SCMOBJ scm_sz = ___VECTORREF(___arg3, 8);

float x;
float y;
float z;
float px;
float py;
float pz;
float sx;
float sy;
float sz;

___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_x, x, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_y, y, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_z, z, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_px, px, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_py, py, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_pz, pz, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sx, sx, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sy, sy, 9);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sz, sz, 9);

___END_CFUN_SCMOBJ_TO_FLOAT(scm_sz, sz, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sy, sy, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sx, sx, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_pz, pz, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_py, py, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_px, px, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_z, z, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_y, y, 9);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_x, x, 9);

float dx = x - px;
float dy = y - py;
float dz = z - pz;

const float* m_rot = ___arg4;
float* m           = ___arg5;

// fourth column
m[12] = ((m_rot[0] - 1.0) * dx + m_rot[3] * dy + m_rot[6] * dz + x)   * sx;
m[13] = ((m_rot[1]) * dx + (m_rot[4] - 1.0) * dy + m_rot[7] * dz + y) * sy;
m[14] = ((m_rot[2]) * dx + m_rot[5] * dy + (m_rot[8] - 1.0) * dz + z) * sz;
UPDATE_TRANSFORMATION_PIVOT_END
))

(define c-update-transformation-pos!
  (c-lambda (scheme-object scheme-object (pointer float)) void
#<<UPDATE_TRANSFORMATION_POS_END

const ___SCMOBJ scm_x  = ___VECTORREF(___arg1, 0);
const ___SCMOBJ scm_y  = ___VECTORREF(___arg1, 4);
const ___SCMOBJ scm_z  = ___VECTORREF(___arg1, 8);
const ___SCMOBJ scm_sx = ___VECTORREF(___arg2, 0);
const ___SCMOBJ scm_sy = ___VECTORREF(___arg2, 4);
const ___SCMOBJ scm_sz = ___VECTORREF(___arg2, 8);

float x;
float y;
float z;
float sx;
float sy;
float sz;
float* m = ___arg3;

___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_x, x, 6);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_y, y, 6);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_z, z, 6);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sx, sx, 6);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sy, sy, 6);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sz, sz, 6);

___END_CFUN_SCMOBJ_TO_FLOAT(scm_sz, sz, 6);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sy, sy, 6);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sx, sx, 6);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_z, z, 6);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_y, y, 6);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_x, x, 6);


// fourth column
m[12] = x * sx;
m[13] = y * sy;
m[14] = z * sz;
UPDATE_TRANSFORMATION_POS_END
))

(define c-update-transformation-rot-and-scl!
  (c-lambda (float float float (pointer float) (pointer float)) void
#<<UPDATE_TRANSFORMATION_ROT_AND_SCL_END
const float x      = ___arg1;
const float y      = ___arg2;
const float z      = ___arg3;
const float* m_rot = ___arg4;
float* m           = ___arg5;

// first column
m[0] = m_rot[0] * x;
m[1] = m_rot[1] * y;
m[2] = m_rot[2] * z;

// second column
m[4] = m_rot[3] * x;
m[5] = m_rot[4] * y;
m[6] = m_rot[5] * z;

// third column
m[8]  = m_rot[6] * x;
m[9]  = m_rot[7] * y;
m[10] = m_rot[8] * z;
UPDATE_TRANSFORMATION_ROT_AND_SCL_END
))

(define (update-transformation-pos! o)
  (with-access o (Transformation translation rotation scaling pivot c-matrix)
    (if pivot
        (c-update-transformation-pivot!
         translation
         pivot
         scaling
         (Quaternion-c-matrix rotation)
         c-matrix
         )
        (c-update-transformation-pos!
         translation
         scaling
         c-matrix))))


(define (update-transformation-rot-and-scl! o)
  (with-access o (Transformation translation scaling rotation pivot c-matrix)
    (normalize! rotation)
    (update-c-matrix! rotation)
    (c-update-transformation-rot-and-scl!
     (vector-ref scaling 0)
     (vector-ref scaling 1)
     (vector-ref scaling 2)
     (Quaternion-c-matrix rotation)
     c-matrix)
    (if pivot
        (c-update-transformation-pivot!
         translation
         pivot
         scaling
         (Quaternion-c-matrix rotation)
         c-matrix))))

;;; methods

(define-generic (Transformation-translate (o Transformation) x y z)
  (with-access o (Transformation translation)
    (set! translation (vector-map + translation (vector x y z)))))

(define-generic (Transformation-scale (o Transformation) x y z)
  (with-access o (Transformation scaling)
    (set! scaling (vector-map * scaling (vector x y z)))))

(define-generic (Transformation-rotate (o Transformation) angle vec)
  (with-access o (Transformation rotation)
    (set! rotation (quaternion* rotation (make-quaternion angle vec)))
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
