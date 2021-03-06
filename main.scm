;; Enable a top-level read-eval-print-loop (REPL)
(thread-start!
  (make-thread
   (lambda ()
     (let loop ()
       (with-exception-catcher
        (lambda (e) (display "Exception:\n") (display e) (newline))
        (lambda () (##repl-debug-main)))
       (loop)))))

;; process REPL lambda in the main thread
(define *main-queue* (box '()))
(define (*mq* fn) (queue-push *main-queue* fn))
(define *current-keymap* (keymap-make))

;; Load some models
;; (define dragon-head-model (load-scene "resources/Dragon/DragonHead.obj"))
;; (define dragon-jaw-model  (load-scene "resources/Dragon/DragonJaw.obj"))
;; (define arne-model        (load-scene "resources/arme_arne/ArmeArne02.DAE"))
(define plane-model       (load-scene "resources/plane/seymourplane_triangulate.dae"))
;; (define astroboy-model    (load-scene "resources/astroboy/astroboy_walk.dae"))
;; (define sharky-model      (load-scene "resources/sharky/Sharky09.DAE"))
(define finn-model        (load-scene "resources/finn/Finn08.DAE"))
(define env-model         (load-scene "resources/environment/Environment03.DAE"))

;; Create some scene nodes
;; (define jaw-node
;;   (instantiate TransformationNode
;;     :transformation (instantiate Transformation
;;                       :pivot (vec 0. 0. -15.))
;;     :children (list dragon-jaw-model)))

;; (define dragon
;;   (instantiate TransformationNode
;;     :children (list dragon-head-model jaw-node)))

;; (define arne
;;   (instantiate TransformationNode
;;     :children (list arne-model)))

(define finn
  (instantiate TransformationNode
    :children (list finn-model)))

;; (define plane
;;   (instantiate TransformationNode
;;     :children (list plane-model)))

(define light
  (instantiate TransformationNode
    :children (list (instantiate LightLeaf))))

(define top
  (instantiate TransformationNode
      :children (list light)));; dragon)
      ;; :transformation (instantiate Transformation
      ;;                     :translation (vec -1.0 -1.0 0.0))))

(define cam (instantiate Camera))
(translate! cam 0.0 200. 400.0)

;; animation module system (mainly for bone animation)
(define animator (instantiate Animator))

;; bullet physics system
(define physics (instantiate BulletPhysics))
(gravity-set! physics 0. -9.82 0.)

(define modules
  (make-modules

   (make-physics-module physics) ;; give the physics subsystem processing time

   (make-animator-module animator top) ;; give the animation subsystem processing time

   (lambda (dt) (update-cameras! top dt))
))

;; key input handling
(keymap-add-key! *current-keymap* #\esc (lambda (k s)
                                          (exit)))
(let ([move-up #f]
      [move-down #f]
      [move-left #f]
      [move-right #f]
      [move-scale 70.0]) 
  (keymap-add-key! *current-keymap* (list 'up 'down 'left 'right)
                   (lambda (k s)
                     (cond 
                       [(equal? k 'up) (set! move-up s)]
                       [(equal? k 'down) (set! move-down s)]
                       [(equal? k 'left) (set! move-left s)]
                       [(equal? k 'right) (set! move-right s)])))  
  (set! modules (add-module (lambda (dt)
                              (if (or move-up move-down move-left move-right)
                                  (translate! cam 
                                         (+   ; x
                                          (if move-left (* -1 move-scale dt) 0.0)
                                          (if move-right (* move-scale dt) 0.0))
                                         0.0  ; y
                                         (+   ; z
                                          (if move-up (* -1 move-scale dt) 0.0)
                                          (if move-down (* move-scale dt) 0.0))))) 
                              modules)))


(if env-model
    (begin
      (scene-add-node! top env-model)))

(if finn-model
    (begin
      (set! modules (cons (make-boids-module (TransformationNode-transformation finn) (car *animations*) animator) modules))

      (scene-add-node! top finn)
      (translate! finn 27. 200. 300.)
      (play (car *animations*) animator)))

(define rb #f)
(define plane #f)

(if plane-model
    (begin 
      (let ([rotor (car (TransformationNode-children (list-ref (TransformationNode-children plane-model) 2)))])
        (set! modules (cons (make-rotator rotor (* 4 pi) (vec 0. 0. 1.)) modules)))
      
      ;; create static collision plane
      (let ([plane-shape (make-rigid-body 
                           physics
                           (instantiate Plane 
                               :normal (vec 0. 1. 0.) 
                               :distance 55.))])
      (mass-set! physics plane-shape 0.)) ;; assigning zero mass makes rb static

      ;; create a rigid box and hook transformation to finn
      (set! rb (make-rigid-body 
                  physics
                  (instantiate AABB 
                      :min (make-vec 3 -15.) 
                      :max (make-vec 3 15.))))

      (set! plane (instantiate TransformationNode
                      :transformation (RigidBody-transformation rb)
                      :children (list plane-model)))
      (translate! plane 0. 60. 0.)
      (rotate! plane pi (vec 0. 1. 0.))
      (synchronize-transform! rb)
      (uniform-scale! plane 4.)

      (linear-damping-set! physics rb 0.8)
      (scene-add-node! top plane)))

(define debug-render #t)

(let* ([can   (instantiate Canvas3D
                :width  800
                :height 600
                :scene  top
                :camera cam)]
       [win (make-window 800 600)]
       [ctx (get-context win)]
       [last-time (time-in-seconds)])
  
  (make-physics-grabber glut-add-mouse-callback glut-add-motion-callback can physics)

  (display "Starting main loop.")
  (newline)
  (display "OpenGL vbo support: ")
  (display (GLContext-vbo? (GLUTContext-gl-context ctx)))
  (newline)
  (display "OpenGL fbo support: ")
  (display (GLContext-fbo? (GLUTContext-gl-context ctx)))
  (newline)
  (set-glut-keyboard-function
   (lambda (key state x y)
     (keymap-handle *current-keymap* key state)))
  (set-glut-special-function
   (lambda (key state x y)
     (let ([key-sym
            (cond
              [(= key 100) 'left]
              [(= key 101) 'up]
              [(= key 102) 'right]
              [(= key 103) 'down]
              [else #f])])
       (if key-sym
           (keymap-handle *current-keymap* key-sym state)))))

  (run-glut-loop (lambda () 
                   (render! ctx can)
                   (if debug-render
                       (bullet-debug-draw))
                   (glut-swap-buffers))
                 
                 (lambda ()
		   (let* ([t (time-in-seconds)]
			  [dt (- t last-time)])
		     (set! last-time t)
		     (process-modules dt modules)
                     (queue-run *main-queue*)                     
                     (##gc) ;; trigger gc to minimize pause times
                     (thread-sleep! 0.005)
                     ))))
