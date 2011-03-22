
; (include "remote-debugger/debuggee.scm")
; (make-rdi-host "localhost:20000")

(thread-start!
  (make-thread
   (lambda ()
     (letrec ([loop
               (lambda ()
                 (with-exception-catcher
                  (lambda (e)
                    (display "exception\n")
                    (display e)
                    (newline))
                  (lambda () (##repl-debug-main)))
                 (loop))])
       (loop)))))


;; (compat-add-resource-path "resources/")

(define *main-queue* (box '()))

(define (queue-next? q)
  (pair? (unbox q)))

(define (queue-push q fn)
  (set-box! q (cons fn (unbox q))))

(define (queue-pop q)
  (let ([n (car (unbox q))])
    (set-box! q (cdr (unbox q)))
    n))

(define (queue-run q)
  (letrec ([loop
            (lambda ()
              (if (queue-next? q)
                  (begin ((queue-pop q))
                         loop)))])
    (loop)))

(define (*mq* fn)
  (queue-push *main-queue* fn))

(define *current-keymap* (keymap-make))


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
  (instantiate TransformationNode :children (list (load-scene arne-path))))

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

(define light (instantiate TransformationNode :children (list (instantiate LightNode))))

(define top (instantiate TransformationNode
                :children (list dragon light) ;; tnode)
                :transformation (instantiate Transformation
				    :translation (vector -1.0 -1.0 0.0))))


(define cam (instantiate Camera))
(move! cam 0.0 0.0 200.0)

(define modules (make-modules (make-rotator dragon (* pi .5) (vector 0.0 1.0 0.0))
                              ;; move light up and down
			      (make-animator (TransformationNode-transformation light)
					     (list
					      (cons 3. (instantiate Transformation
							   :translation (vector 0. 100. -100.)))
					      (cons 6. (instantiate Transformation
							   :translation (vector 0. -100. -100.)))
					      (cons 9. (instantiate Transformation
							   :translation (vector 0. 100. -100.)))))

			      ;; move the dragon jaw
			      (make-animator (TransformationNode-transformation jaw-node)
					     (list
					      (cons 2. (instantiate Transformation
							   :rotation (mk-Quaternion (/ pi 4) (vector 1. 0. 0.))))
					      (cons 4. (instantiate Transformation))

					      (cons 6. (instantiate Transformation
					      		   :rotation (mk-Quaternion (/ pi 4) (vector 1. 0. 0.))))
					      ))))


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
		     ;; (with-access
		     ;;  (TransformationNode-transformation tnode)
		     ;;  (Transformation translation)
		     ;;  (if (> (vector-ref translation 0) 2.)
		     ;; 	  (set! translation (vector 0. 0. 0.))
		     ;; 	  (move! tnode .1 .1 .0)))
		     (thread-sleep! 0.005)))))
