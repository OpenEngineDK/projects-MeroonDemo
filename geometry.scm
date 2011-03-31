(define-class Mesh Object
  ([= geotype  :immutable :initializer (lambda () 'triangles)]
   [= indices  :immutable]
   [= vertices :immutable]
   [= normals  :immutable :initializer (lambda () #f)]
   [= uvs      :immutable :initializer (lambda () #f)]
   ;; [= datablocks :immutable]
   [= texture :immutable :initializer (lambda () #f)]))

(define-class Light Object 
  ([= ambient  :initializer (lambda () (vector .2 .2 .2 1.))]
   [= diffuse  :initializer (lambda () (vector .8 .8 .8 1.))]
   [= specular :initializer (lambda () (vector 0. 0. 0. 1.))]))

(define-class PointLight Light
  ([= constant-att  :initializer (lambda () 1.)]
   [= linear-att    :initializer (lambda () 0.)]
   [= quadratic-att :initializer (lambda () 0.)]))
