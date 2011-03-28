;; New object (canvas + scene) abstractions in Scheme
    
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
  ([= geotype  :immutable :initializer (lambda () 'triangles)]
   [= indices  :immutable]
   [= vertices :immutable]
   [= normals  :immutable :initializer (lambda () #f)]
   [= uvs      :immutable :initializer (lambda () #f)]
   ;; [= datablocks :immutable]
   [= texture :immutable :initializer (lambda () #f)]))

(define-class ShaderNode SceneParent ;; Effect
  ([* tags :immutable]))


(define-class Light Object 
  ([= ambient  :initializer (lambda () (vector .2 .2 .2 1.))]
   [= diffuse  :initializer (lambda () (vector .8 .8 .8 1.))]
   [= specular :initializer (lambda () (vector 0. 0. 0. 1.))]))

(define-class PointLight Light
  ([= constant-att  :initializer (lambda () 1.)]
   [= linear-att    :initializer (lambda () 0.)]
   [= quadratic-att :initializer (lambda () 0.)]))

(define-class LightNode Scene
  ([= light :immutable :initializer (lambda () (instantiate PointLight))]))

(define-generic (scene-add-node! (node SceneParent) (child Scene))
  (with-access node (SceneParent children)
    (set! children (cons child children))))

(define-generic (scene-remove-node! (node SceneParent) (child Scene))
  (with-access node (SceneParent children)
    (set! children (remove child children))))

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
  (move! (Camera-view cam) (- x) (- y) (- z)))

(define-generic (scale! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not scalable")))

(define-method (scale! (o Transformation) x y z)
  (Transformation-scale o x y z)
  (update-transformation-rot-and-scl! o))

(define-method (scale! (node TransformationNode) x y z)
  (scale! (TransformationNode-transformation node) x y z))

(define (uniform-scale! o s) 
  (scale! o s s s))

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
