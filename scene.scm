(define-class Scene Object 
  ([= name :initializer (lambda () #f)]
   [= info :initializer (lambda () #f)]))

(define-class SceneNode Scene
  ([= children :mutable
      :initializer list]))

(define-class SceneLeaf Scene
())

(define-class TransformationNode SceneNode
  ([= transformation
      :initializer (lambda () (instantiate Transformation))]))

;; a BoneNode is essentially a TransformationNode with a list of vertex weights
(define-class BoneNode SceneNode
  ([= offset ;; the bind pose transformation
      :immutable
      :initializer (lambda () (instantiate Transformation))]
   [= transformation ;; the current transformation of this bone
      :initializer (lambda () (instantiate Transformation))]
   [= acc-transformation ;; accumulated transformation place-holder (used for skinning)
      :initializer (lambda () (instantiate Transformation))]
   [= c-weights ;; c-structure containing the list of vertex x weight pairs.
      :immutable ]
   [= dirty  ;; dirty flag. Animator sets to true, skinner sets to false.
      :initializer (lambda () #f)] 
   ))

(define-class ShaderNode SceneNode ;; Effect
  ([* tags :immutable]))

(define-class MeshLeaf SceneLeaf
  ([= mesh ]))

(define-class LightLeaf SceneLeaf
  ([= light :immutable :initializer (lambda () (instantiate PointLight))]))

(define-generic (scene-add-node! (node SceneNode) (child Scene))
  (with-access node (SceneNode children)
    (set! children (cons child children))))

(define-generic (scene-remove-node! (node SceneNode) (child Scene))
  (with-access node (SceneNode children)
    (set! children (remove child children))))

(define-method (show (o TransformationNode) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a TNode: transformation" stream)
    (show (TransformationNode-transformation o) stream)
    (display ">" stream)))

(define-method (show (o MeshLeaf) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a MeshLeaf>" stream)))

(define-method (rotate! (o TransformationNode) angle vec)
  (rotate! (TransformationNode-transformation o) angle vec))

(define-method (move! (node TransformationNode) x y z)
  (move! (TransformationNode-transformation node) x y z))

(define-method (scale! (node TransformationNode) x y z)
  (scale! (TransformationNode-transformation node) x y z))
