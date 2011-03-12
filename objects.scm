;; New object abstractions in Scheme

(define-class Canvas Object
  ([= width  :immutable]
   [= height :immutable]))

(define-class Canvas3D Canvas
  ([= scene :immutable]
   [= view  :immutable]))

(define-class Scene Object ())

(define-class SceneParent Scene
  ([= children :mutable
      :initializer list]))

(define-class TransformationNode SceneParent
  ([= transformation :immutable
      :initializer (lambda () (instantiate Transformation))]))

(define-class MeshNode Scene
  ([= geotype :immutable]
   [= datablocks :immutable]))

(define-generic (move! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not movable")))

(define-method (move! (o Transformation) x y z)
  (Transformation-translate o x y z))

(define-method (move! (node TransformationNode) x y z)
  (move! (TransformationNode-transformation node) x y z))

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
