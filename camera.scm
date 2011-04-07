(define pi 3.14159265358979323846264338328)

;; Parameterized projection matrix
;; Use update-proj! to update the underlying c-matrix representation 
;; note: This is a temporary hack!
(define-class Projection Object
  ([= aspect   :immutable :initializer (lambda () (/ 4.0 3.0))]
   [= fov      :immutable :initializer (lambda () (/ pi 4.0))]
   [= near     :immutable :initializer (lambda () 3.0)]
   [= far      :immutable :initializer (lambda () 5000.0)]
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

;; Currently this is handled (hackishly) by letting move! and rotate!
;; do inverse operations. This hack easily goes away when the c-matrix
;; is pulled out of the transformation abstraction.

(define-class Camera Object
  ([= proj :initializer (lambda () (instantiate Projection))]
   [= view :initializer (lambda () (instantiate Transformation))]))

(define-method (rotate! (cam Camera) angle vec)
  (rotate! (Camera-view cam) (- angle) vec))

(define-method (translate! (cam Camera) x y z)
  (translate! (Camera-view cam) (- x) (- y) (- z)))
