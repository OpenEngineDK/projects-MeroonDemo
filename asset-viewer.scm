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


(define top (instantiate TransformationNode))

(define cam (instantiate Camera))
;; (define cam-trans (instantiate TransformationNode))

;; animation module system (mainly for bone animation)
(define animator (instantiate Animator))

(define modules
  (make-modules
   (make-animator-module animator top) ;; give the animation subsystem processing time
   (lambda (dt) (update-cameras! top dt))
))


;; key input handling
(define *current-keymap* (keymap-make))
(keymap-add-key! *current-keymap* #\esc (lambda (k s)
                                          (exit)))

(let* ([t2 (instantiate TransformationNode :children (list (instantiate CameraLeaf :camera cam)))]
       [t1 (instantiate TransformationNode :children (list t2))]

       [move-up #f]
       [move-down #f]
       [move-left #f]
       [move-right #f]

       [rot-up #f]
       [rot-down #f]
       [rot-left #f]
       [rot-right #f]

       [move-scale 700.0]
       [rot-scale 1.0]
       )
  (translate! t2 0. 0. 400.)
  (scene-add-node! top t1)
  (keymap-add-key! *current-keymap* (list #\w #\a #\s #\d 'up 'down 'left 'right)
                   (lambda (k s)
                     (cond 
                       [(equal? k #\w) (set! move-up s)]
                       [(equal? k #\s) (set! move-down s)]
                       [(equal? k #\a) (set! move-left s)]
                       [(equal? k #\d) (set! move-right s)]

                       [(equal? k 'up) (set! rot-up s)]
                       [(equal? k 'down) (set! rot-down s)]
                       [(equal? k 'left) (set! rot-left s)]
                       [(equal? k 'right) (set! rot-right s)]


)))    
  (set! modules 
        (add-module (lambda (dt)
                      (if (or move-up move-down move-left move-right)
                          (translate! t2
                                      (+   ; x
                                       (if move-left (* -1. move-scale dt) 0.0)
                                       (if move-right (* move-scale dt) 0.0))
                                      0.0  ; y
                                      (+   ; z
                                       (if move-up (* -1. move-scale dt) 0.0)
                                       (if move-down (* move-scale dt) 0.0))))
                      (if rot-up
                          (rotate! t1 (* dt rot-scale) (vec 1. 0. 0.)))

                      (if rot-down
                          (rotate! t1 (* dt rot-scale) (vec -1. 0. 0.)))

                      (if rot-left
                          (rotate! t1 (* dt rot-scale) (vec 0. 1. 0.)))

                      (if rot-right
                          (rotate! t1 (* dt rot-scale) (vec 0. -1. 0.))))
                    modules)))


(define screen-width 800)
(define screen-height 600)

(define can (instantiate Canvas3D
                :width  screen-width
                :height screen-height
                :scene  top
                :camera cam))

(define win (make-window screen-width screen-height))

(define models '())

(map (lambda (f) 
       (let ([m (load-scene f)])
         (if m
             (set! models (cons (instantiate TransformationNode :children (list m)) models))
             (begin
               (display "Error loading model file: ")
               (display f)
               (newline)))))
     (cdr (command-line)))

(map (lambda (m) (scene-add-node! top m)) models)

(let* ([ctx (get-context win)]
       [last-time (time-in-seconds)])
  
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
                   (glut-swap-buffers))
                 
                 (lambda ()
		   (let* ([t (time-in-seconds)]
			  [dt (- t last-time)])
		     (set! last-time t)

		     (process-modules dt modules)
                     (queue-run *main-queue*)

                     (##gc) ;; trigger gc to minimize pause times
                     (glut-redisplay)
                     ;;(thread-sleep! 0.005)
                     ))))
