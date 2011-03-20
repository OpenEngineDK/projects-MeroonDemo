;; New object abstractions in Scheme

(define pi 3.14159265358979323846264338328)

(c-define-type FloatArray (pointer "float"))

(define-class Projection Object
  ([= aspect   :immutable :initializer (lambda () (/ 4.0 3.0))]
   [= fov      :immutable :initializer (lambda () (/ pi 4.0))]
   [= near     :immutable :initializer (lambda () 1.0)]
   [= far      :immutable :initializer (lambda () 3000.0)]
   [= c-matrix :immutable 
      :initializer (c-lambda () FloatArray
		     "float* m = new float[16];
		     ___result_voidstar = m;"
		     )]))

(define (update-proj! o)
  ((c-lambda (float float float float FloatArray) void
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
    
(define-class Camera Object
  ([= proj   :mutable :initializer 
      (lambda ()
	(let ([p (instantiate Projection)])
	  (update-proj! p)
	  p))]
   [= view   :mutable :initializer (lambda () (instantiate Transformation))]))

(define-class Canvas Object
  ([= width  :immutable]
   [= height :immutable]))

(define-class Canvas3D Canvas
  ([= scene  :immutable]
   [= camera :immutable]))

(define-class Scene Object ())

(define-class SceneParent Scene
  ([= children :mutable
      :initializer list]))

(define-class TransformationNode SceneParent
  ([= transformation :immutable
      :initializer (lambda () (instantiate Transformation))]))

(define-class MeshNode Scene
  ([= geotype  :immutable]
   [= indices  :immutable]
   [= vertices :immutable]
   [= uvs      :immutable :initializer (lambda () #f)]
   ;; [= datablocks :immutable]
   [= texture :immutable :initializer (lambda () #f)]))

(define-class ShaderNode SceneParent ;; Effect
  ([* tags :immutable]))

(define-generic (rotate! (o) angle vec)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " can not be rotated")))

(define-method (rotate! (o Transformation) angle vec)
  (Transformation-rotate o angle vec)
  (update-transformation-rot-and-scl! o))

(define-method (rotate! (o TransformationNode) angle vec)
  (rotate! (TransformationNode-transformation o) angle vec))

(define-method (rotate! (cam Camera) angle vec)
  (rotate! (Camera-view cam) angle vec))

(define-generic (move! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not movable")))

(define-method (move! (o Transformation) x y z)
  (Transformation-translate o x y z)
  (update-transformation-pos! o))

(define-method (move! (node TransformationNode) x y z)
  (move! (TransformationNode-transformation node) x y z))

(define-method (move! (cam Camera) x y z)
  (move! (Camera-view cam) x y z))

(define-generic (scale! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not scalable")))


(define-method (scale! (o Transformation) x y z)
  (Transformation-scale o x y z)
  (update-transformation-rot-and-scl! o))

(define-method (scale! (node TransformationNode) x y z)
  (scale! (TransformationNode-transformation node) x y z))


(define-method (show (o Canvas3D) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a Canvas3D: scene(" stream)
    (show (Canvas3D-scene o) stream)
    (display ")>" stream)))

(define-method (show (o TransformationNode) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a TNode: transformation" stream)
    (show (TransformationNode-transformation o) stream)
    (display ">" stream)))

(define-method (show (o MeshNode) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a MeshNode>" stream)))
