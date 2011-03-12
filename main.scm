
;(include "remote-debugger/debuggee.scm")
;(make-rdi-host "localhost:20000")


; (thread-start!
;  (make-thread
;   (lambda () (##repl-debug-main))))

(define mesh (instantiate MeshNode
                :geotype 'triangles
                :datablocks
                (list 
                 (cons 'indices  (make-datablock '((0) (1) (2))))
                 (cons 'vertices (make-datablock '((0. 0. 0.)
                                                   (1. 0. 0.)
                                                   (0. 1. 0.)))))))
(define tnode (instantiate TransformationNode
                :children (list mesh)))
(define top   (instantiate TransformationNode
                :children (list tnode)
                :transformation (instantiate Transformation
                                  :translation (vector -1.0 -1.0 0.0))))

(let* ([can   (instantiate Canvas3D
                :width  1024
                :height 768
                :scene  top
                :view   #f)]
       [win (make-window 1024 768)]
       [ctx (get-context win)])
  (display "Starting main loop.")
  (newline)
  (run-glut-loop (lambda ()
                   (render! ctx can)
                   (with-access
                       (TransformationNode-transformation tnode)
                       (Transformation translation)
                     (if (> (vector-ref translation 0) 2.)
                         (set! translation (vector 0. 0. 0.))
                         (move! tnode .1 .1 .0))
                     (thread-sleep! 0.1)))))
