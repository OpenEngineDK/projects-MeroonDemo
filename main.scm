
; (include "remote-debugger/debuggee.scm")
; (make-rdi-host "localhost:20000")

(thread-start!
  (make-thread
    ;; (lambda () 
    ;;   (with-exception-handler 
    ;;     (lambda (e) 
    ;;       (show "wtf..")
    ;;       (show e)
          
    ;;       )
        (lambda () (##repl-debug-main))))
    ;; ))

;; (compat-add-resource-path "resources/")

(define dragon-head-path "resources/Dragon/DragonHead.obj")
(define dragon-jaw-path "resources/Dragon/DragonJaw.obj")
(define arne-path "resources/arme_arne/ArmeArne02.DAE")
(define plane-path "resources/plane/seymourplane_triangulate.dae")

(define dragon-head
    (load-scene dragon-head-path))

(define dragon-jaw
    (load-scene dragon-jaw-path))

(define jaw-node (instantiate TransformationNode
                   :transformation (instantiate Transformation :pivot (vector 0. 0. -15.)) 
                   :children (list dragon-jaw)))

(define dragon (instantiate TransformationNode :children (list dragon-head jaw-node)))

(define arne 
  (load-scene arne-path))

(define plane 
  (load-scene plane-path))

(define mesh (instantiate MeshNode
                :geotype 'triangles
                :indices (make-datablock '((0) (1) (2)))
		:vertices (make-datablock '((0. 0. 0.)
					    (1. 0. 0.)
					    (0. 1. 0.)))))
(define shn (instantiate ShaderNode
                :children (list mesh)
                :tags 'blue))


(define tnode (instantiate TransformationNode
                :children (list shn)))

(define rot-angle 0.)
(define rot-delta 0.01)

(define top (instantiate TransformationNode
                :children (list dragon) ;; tnode)
                :transformation (instantiate Transformation
				    :translation (vector -1.0 -1.0 0.0))))


(define cam (instantiate Camera))
(move! cam 0.0 0.0 200.0)


(define modules (make-modules (make-rotator dragon 0.01 (vector 0.0 1.0 0.0))))

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
                   (process-modules modules)
		   (render! ctx can)
		   (with-access
		    (TransformationNode-transformation tnode)
		    (Transformation translation)
		    (if (> (vector-ref translation 0) 2.)
			(set! translation (vector 0. 0. 0.))
			(move! tnode .1 .1 .0)))
		   (if (<= rot-angle 0.)
		       (set! rot-delta .01)
		       (if (>= rot-angle (* pi .2))
			   (set! rot-delta -.01)
			   #t))
		   (set! rot-angle (+ rot-angle rot-delta))
		   (rotate! jaw-node rot-delta (vector 1. 0. 0.))
		   ;; (rotate! cam .01 (vector 0. 1. 0.))
		   (thread-sleep! 0.005))))