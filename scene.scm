;; scene base class. Generic methods should report error on this type.
(define-class Scene Object 
  ([= name :initializer (lambda () #f)]
   [= info :initializer (lambda () #f)]))

;; All scene nodes must descend from this class.
;; Methods can take default action for all nodes on this type.
(define-class SceneNode Scene
  ([= children :mutable
      :initializer list]))

;; All leafs must descend from this class
;; Methods can take default action for all leafs on this type.
(define-class SceneLeaf Scene
())

;; A TransformationNode defines a local coordinate system for its subtree.
;; (... or a transformation node translates, rotates, and scales its subtree).
(define-class TransformationNode SceneNode
  ([= transformation
      :initializer (lambda () (instantiate Transformation))]))

;; A BoneNode is essentially a TransformationNode with a list of vertex weights
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

;; A Leaf containing geometry
(define-class MeshLeaf SceneLeaf
  ([= mesh ]))

;; A Leaf containing a light source
(define-class LightLeaf SceneLeaf
  ([= light :immutable :initializer (lambda () (instantiate PointLight))]))

;; generic operations on a scene
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

(define-method (translate! (node TransformationNode) x y z)
  (translate! (TransformationNode-transformation node) x y z))

(define-method (scale! (node TransformationNode) x y z)
  (scale! (TransformationNode-transformation node) x y z))

(define-method (rotation-set! (o TransformationNode) angle axis)
  (rotation-set! (TransformationNode-transformation o angle axis)))

(define-method (translation-set! (o TransformationNode) x y z)
  (translation-set! (TransformationNode-transformation o x y z)))

(define-method (scaling-set! (o TransformationNode) x y z)
  (scaling-set! (TransformationNode-transformation o x y z)))
