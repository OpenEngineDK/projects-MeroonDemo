;; New object abstractions in Scheme

(define-class Canvas Object
  ([= width  :immutable]
   [= height :immutable]))

(define-class Canvas3D Canvas
  ([= scene :immutable]
   [= view  :immutable]))

(define-class Scene Object
  ())
  ;; ([= children :mutable
  ;;     :initializer (lambda () '())]))

(define-class TransformationNode Scene
  ([= children :mutable
      :initializer (lambda () '())]
   [= position :mutable
      :initializer (lambda () (make-vector 3 0.0))]
   [= rotation :immutable
      :initializer (lambda () #f)]
   [= scale :immutable
      :initializer (lambda () (make-vector 3 0.0))]))

(define-class MeshNode Scene
  ([= geotype :immutable]
   [= datablocks :immutable]))

(define-generic (move (o) x y z)
  (error "Move is not supported on this object"))

(define-method (move (node TransformationNode) x y z)
  (with-access node (TransformationNode position)
    (vector-set! position 0 (fl+ x (vector-ref position 0)))
    (vector-set! position 1 (fl+ y (vector-ref position 1)))
    (vector-set! position 2 (fl+ z (vector-ref position 2)))))

(define-method (show (o Canvas3D) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a Canvas3D: scene(" stream)
    (show (Canvas3D-scene o) stream)
    (display ")>" stream)))

(define-method (show (o TransformationNode) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a TNode: position(" stream)
    (show (TransformationNode-position o) stream)
    (display ")>" stream)))
