(define-class Canvas Object
  ([= width  :immutable]
   [= height :immutable]))

(define-class Canvas3D Canvas
  ([= scene  :immutable]
   [= camera :immutable]))

(define-method (show (o Canvas3D) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "#<a Canvas3D: scene(" stream)
    (show (Canvas3D-scene o) stream)
    (display ")>" stream)))
