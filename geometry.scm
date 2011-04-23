(define-class VertexAttribute Object
  ([= elm-type  :immutable]
   [= elm-size  :immutable]
   [= elm-count :immutable]
   [= data      :immutable]))

(define-method (initialize! (o VertexAttribute))
  (make-will o (lambda (x)
		 (with-access x (VertexAttribute data)
	           ((c-lambda ((pointer void)) void
		      "if (___arg1) delete[] ___arg1;")
                    data))))
  (call-next-method))

(define-class Mesh Object
  ([= geotype  :immutable :initializer (lambda () 'triangles)]
   [= indices  :immutable]
   [= vertices :immutable]
   [= normals  :immutable :initializer (lambda () #f)]
   [= uvs      :immutable :initializer (lambda () #f)]
   [= colors   :immutable :initializer (lambda () #f)]
   [= texture  :immutable :initializer (lambda () #f)]))

;; an animated mesh is a Mesh which contains a list of the bones that affect it.
(define-class AnimatedMesh Mesh
  ([= bind-pose-vertices ;; the original "bind pose" mesh data 
     :immutable]
   [= bind-pose-normals 
      :immutable]
   [= bones ;; bones that affect this mesh
      :immutable :initializer list]))

(define-class Light Object 
  ([= ambient  :initializer (lambda () (vec .2 .2 .2 1.))]
   [= diffuse  :initializer (lambda () (vec .8 .8 .8 1.))]
   [= specular :initializer (lambda () (vec 0. 0. 0. 1.))]))

(define-class PointLight Light
  ([= constant-att  :initializer (lambda () 1.)]
   [= linear-att    :initializer (lambda () 0.)]
   [= quadratic-att :initializer (lambda () 0.)]))
