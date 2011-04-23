(define pi 3.14159265358979323846264338328)

;; Parameterized projection matrix
;; Use update-proj! to update the underlying c-matrix representation 
;; note: This is a temporary hack!
(define-class Projection Object
  ([= aspect   :immutable :initializer (lambda () (/ 4.0 3.0))]
   [= fov      :immutable :initializer (lambda () (/ pi 4.0))]
   [= near     :immutable :initializer (lambda () 3.0)]
   [= far      :immutable :initializer (lambda () 7000.0)]
   [= c-matrix :immutable 
      :initializer (c-lambda () (pointer "float")
		     "float* m = new float[16];
		     ___result_voidstar = m;"
		     )]))

(define-method (initialize! (o Projection))
  ;; free the c-matrix when object is reclaimed by the gc.
  (update-proj! o)
  (make-will o (lambda (x) 
		 (with-access x (Projection c-matrix)
	           ((c-lambda ((pointer float)) void
		      "delete[] ___arg1;")
                    c-matrix))))
  (call-next-method))

(define (update-proj! o)
  ((c-lambda (float float float float (pointer "float")) void
#<<UPDATE_PROJECTION_END
float aspect = ___arg1;
float fov    = ___arg2;
float near   = ___arg3;
float far    = ___arg4;
float* m     = ___arg5;

float f = 1.0f / tanf(fov * 0.5f);
float a = (far + near) / (near - far);
float b = (2.0f * far * near) / (near - far);

// first column
m[0] = f / aspect;
m[1] = 0.0f;
m[2] = 0.0f;
m[3] = 0.0f;

// second column
m[4] = 0.0f;
m[5] = f;
m[6] = 0.0f;
m[7] = 0.0f;

// third column
m[8]  = 0.0f;
m[9]  = 0.0f;
m[10] = a;
m[11] = -1.0f;

// fourth column
m[12] = 0.0f;
m[13] = 0.0f;
m[14] = b;
m[15] = 0.0f;
UPDATE_PROJECTION_END
  )
   (Projection-aspect o)
   (Projection-fov o)
   (Projection-near o)
   (Projection-far o)
   (Projection-c-matrix o)))

;; Camera abstraction
;; A camera is simply a projection transformation combined with a
;; coordinate space transformation.

;; Note that a camera transformation matrix behaves like an inverse
;; scene transformation matrix, since it transforms from world
;; space to camera space. 

(define-class Camera Object
  ([= proj :initializer (lambda () (instantiate Projection))]
   [= view :initializer (lambda () (instantiate Transformation))]))

(define-method (rotate! (cam Camera) angle vec)
  (rotate! (Camera-view cam) angle vec))

(define-method (translate! (cam Camera) x y z)
  (translate! (Camera-view cam) x y z))

(c-declare #<<C-DECLARE-END
#include <Math/Matrix.h>
#include <Math/Vector.h>

using OpenEngine::Math::Matrix;
using OpenEngine::Math::Vector;

Matrix<4,4,float> proj_m;
Matrix<4,4,float> view_m;

C-DECLARE-END
)

(c-define (set-vec v x y z)
    (scheme-object float float float) void "set_vector_scm" ""
  (vec-set! v 0 x)
  (vec-set! v 1 y)
  (vec-set! v 2 z))

;; x and y in window space [0;1] and z is the target depth value [0;1] 
(define (unproject cam x y z)
  (with-access cam (Camera proj view)
    ((c-lambda ((pointer "float")) void 
#<<SET-PROJ-END
proj_m = Matrix<4,4,float>(___arg1);
proj_m.Transpose();
SET-PROJ-END
) 
     (Projection-c-matrix proj))
    (with-access view (Transformation translation rotation)
      ((c-lambda (float float float float float float float) void
#<<SET-VIEW-END
view_m = Matrix<4,4,float>();

const float pos_x  = ___arg1;
const float pos_y  = ___arg2;
const float pos_z  = ___arg3;

const float w  = ___arg4;
const float x  = ___arg5;
const float y  = ___arg6;
const float z  = ___arg7;

// fourth column
view_m(0,3) = -pos_x;
view_m(1,3) = -pos_y;
view_m(2,3) = -pos_z;

// first column
view_m(0,0) = 1-2*y*y-2*z*z;
view_m(1,0) = 2*x*y-2*w*z;
view_m(2,0) = 2*x*z+2*w*y;

// second column
view_m(0,1) = 2*x*y+2*w*z;
view_m(1,1) = 1-2*x*x-2*z*z;
view_m(2,1) = 2*y*z-2*w*x;

// third column
view_m(0,2) = 2*x*z-2*w*y;
view_m(1,2) = 2*y*z+2*w*x;
view_m(2,2) = 1-2*x*x-2*y*y;

SET-VIEW-END
)
       (vec-ref translation 0)
       (vec-ref translation 1)
       (vec-ref translation 2)
       (quat-w rotation)
       (quat-x rotation)
       (quat-y rotation)
       (quat-z rotation))))
  (let ([point (vec 0. 0. 0.)])
    ((c-lambda (float float float scheme-object) void
#<<CALC-PROJ-END
const float x  = ___arg1;
const float y  = ___arg2;
const float z  = ___arg3;
Matrix<4,4,float> inv = (proj_m * view_m).GetInverse();
Vector<4,float> pos4(x * 2.0 - 1.0, y * 2.0 - 1.0, z, 1.0);
pos4 = inv * pos4;
pos4 = Vector<4,float>(pos4[0]/pos4[3], 
                       pos4[1]/pos4[3], 
                       pos4[2]/pos4[3],
                       1.0);

set_vector_scm(___arg4, pos4[0], pos4[1], pos4[2]);
CALC-PROJ-END
)
     x y z point)
    point))


(define (update-cameras! scene dt)
  (*update-cameras! scene (instantiate Transformation) dt))

(define-generic  (*update-cameras! (scene Scene) tos dt)
  (error "Unsupported Scene"))

(define-method (*update-cameras! (leaf SceneLeaf) tos dt)
#f)

(define-method (*update-cameras! (node SceneNode) tos dt)
  (do ([children (SceneNode-children node) (cdr children)])
      ((null? children))
    (*update-cameras! (car children) tos dt)))

(define-method (*update-cameras! (node TransformationNode) tos dt)
  (with-access node (TransformationNode transformation)
    (with-access transformation (Transformation rotation)
      (quat-normalize! rotation))
    (let ([push-trans (compose-trans tos transformation)])
      (with-access push-trans (Transformation rotation)
        (quat-normalize! rotation))
      (do ([children (TransformationNode-children node) (cdr children)])
          ((null? children))
          (*update-cameras! (car children) push-trans dt)))))

(define trans-factor 5.)
(define rot-factor 5.)

(define-method (*update-cameras! (leaf CameraLeaf) tos dt)
  (with-access tos (Transformation translation rotation)
    (with-access (CameraLeaf-camera leaf) (Camera view)
      (let* ([old-vec (Transformation-translation view)]
             [old-rot  (Transformation-rotation view)]
             [new-vec (rotate-vec translation (quat-conjugate rotation))]
             [new-rot rotation])
        (set! view (instantiate Transformation 
                       :translation (vec-interp old-vec new-vec (* dt trans-factor))
                       :rotation (quat-interp old-rot new-rot (* dt rot-factor))))))))
