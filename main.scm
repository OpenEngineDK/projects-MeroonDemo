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
(define dragon-head-model (load-scene "resources/Dragon/DragonHead.obj"))
(define dragon-jaw-model  (load-scene "resources/Dragon/DragonJaw.obj"))
(define arne-model        (load-scene "resources/arme_arne/ArmeArne02.DAE"))
(define plane-model       (load-scene "resources/plane/seymourplane_triangulate.dae"))
(define astroboy-model    (load-scene "resources/astroboy/astroboy_walk.dae"))
(define sharky-model      (load-scene "resources/sharky/Sharky09.DAE"))
(define finn-model        (load-scene "resources/finn/Finn08.DAE"))

;; Create some scene nodes
(define jaw-node
  (instantiate TransformationNode
    :transformation (instantiate Transformation
                      :pivot (vector 0. 0. -15.))
    :children (list dragon-jaw-model)))

(define dragon
  (instantiate TransformationNode
    :children (list dragon-head-model jaw-node)))

(define arne
  (instantiate TransformationNode
    :children (list arne-model)))

(define finn
  (instantiate TransformationNode
    :children (list finn-model)))

(define light
  (instantiate TransformationNode
    :children (list (instantiate LightLeaf))))

(define top
  (instantiate TransformationNode
      :children (list dragon light)
      :transformation (instantiate Transformation
                          :translation (vector -1.0 -1.0 0.0))))

(define cam (instantiate Camera))
(move! cam 0.0 0.0 400.0)

;; animation module system (mainly for bone animation)
(define animator (instantiate Animator))

(define modules
  (make-modules
   (make-boids-module (TransformationNode-transformation finn) (car *animations*) animator)
   (make-animator-module animator top) ;; give the animation subsystem processing time
   (make-rotator dragon (* pi .5) (vector 0.0 1.0 0.0))
   ;; move light up and down
   (make-animator ;; deprecated stuff (see animation.scm)
    (TransformationNode-transformation light)
    (list (cons 3. (instantiate Transformation
                     :translation (vector 0. 100. 500.)))
          (cons 6. (instantiate Transformation
                     :translation (vector 0. -100. 500.)))
          (cons 9. (instantiate Transformation
                     :translation (vector 0. 100. 500.)))))
   ;; move the dragon jaw
   (make-animator ;; deprecated stuff (see animation.scm)
    (TransformationNode-transformation jaw-node)
    (list (cons 2. (instantiate Transformation
                     :rotation (make-quaternion (/ pi 4)
                                                (vector 1. 0. 0.))))
          (cons 4. (instantiate Transformation))
          
          (cons 6. (instantiate Transformation
                     :rotation (make-quaternion (/ pi 4)
                                                (vector 1. 0. 0.))))))))


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
                                  (move! cam 
                                         (+   ; x
                                          (if move-left (* -1 move-scale dt) 0.0)
                                          (if move-right (* move-scale dt) 0.0))
                                         0.0  ; y
                                         (+   ; z
                                          (if move-up (* -1 move-scale dt) 0.0)
                                          (if move-down (* move-scale dt) 0.0))))) 
                              modules)))


;; setup some fishy animation demo
;; (if sharky-model
;;     (begin
;;       (scene-add-node! top sharky-model)
;;       (move! dragon 0. 100 0.)
;;       (play (cadr *animations*) animator)))

(if finn-model
    (begin
      (scene-add-node! top finn)
      (move! finn 27. 0. 300.)
      (play (car *animations*) animator)))

(let* ([can   (instantiate Canvas3D
                :width  1024
                :height 768
                :scene  top
                :camera cam)]
       [win (make-window 1024 768)]
       [ctx (get-context win)]
       [last-time (time-in-seconds)])
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
		   (let* ([t (time-in-seconds)]
			  [dt (- t last-time)])
		     (set! last-time t)
		     (process-modules dt modules)
                     (queue-run *main-queue*)
                     (render! ctx can)
                     (##gc) ;; trigger gc to minimize pause times
                     (thread-sleep! 0.005)
                     ))))
