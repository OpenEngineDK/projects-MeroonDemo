
; (include "remote-debugger/debuggee.scm")
; (make-rdi-host "localhost:20000")

;; (thread-start!
;;   (make-thread
;;     (lambda () 
;;       (with-exception-handler 
;;         (lambda (e) 
;;           (show "wtf..")
;;           (show e)
          
;;           )
;;         (lambda () (##repl-debug-main))))
;;     ))

;; (compat-add-resource-path "resources/")

(define dragon-head
    (load-scene "resources/Dragon/DragonHead.obj"))

(define dragon-jaw
    (load-scene "resources/Dragon/DragonJaw.obj"))
;;(compat-load-model "Dragon/DragonHead.obj"))

(define mesh (instantiate MeshNode
                :geotype 'triangles
                :datablocks
                (list 
                 (cons 'indices  (make-datablock '((0) (1) (2))))
                 (cons 'vertices (make-datablock '((0. 0. 0.)
                                                   (1. 0. 0.)
                                                   (0. 1. 0.)))))))
(define shn   (instantiate ShaderNode
                :children (list mesh)
                :tags 'blue))


(define tnode (instantiate TransformationNode
                :children (list shn)))
(define top   (instantiate TransformationNode
                :children (list dragon-head dragon-jaw) ;; tnode)
                :transformation (instantiate Transformation
                                  :translation (vector -1.0 -1.0 0.0))))


(define cam (instantiate Camera))
(move! cam 0.0 0.0 200.0)

(let* ([can   (instantiate Canvas3D
                :width  1024
                :height 768
                :scene  top
                :camera cam)]
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

