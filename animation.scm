;; animation base class
(define-class Animation Object
  ([= name
      :immutable 
      :initializer string]
   [= duration
      :immutable 
      :initializer (lambda () 0.0)]
   [= ticks-per-second
      :immutable 
      :initializer (lambda () 0.0)]
   ))

;; evaluate child animations simultaniously
(define-class ParallelAnimation Animation
  ([= child-animations
      :immutable
      :initialiser vec]
   ))

;; evaluate child animations sequentually
(define-class SequentialAnimation Animation
  ([= child-animations
      :immutable
      :initialiser list]
   ))

;; contains a bone to be updated according to time x transformation pairs.
(define-class BoneAnimation Animation
  ([= bone 
      :immutable]
   [= position-keys 
      :immutable]
   [= rotation-keys 
      :immutable]
   [= scaling-keys 
      :immutable]
   ))

(define-class TransformationAnimation Animation
  ([= transformation-node
      :immutable]
   [= position-keys 
      :immutable]
   [= rotation-keys 
      :immutable]
   [= scaling-keys 
      :immutable]
   ))

(define-class PlayInfo Object
  ([= time :initializer (lambda () 0.0)]
   [= speed :initializer (lambda () 1.0)]
))

(define-class Animator Object
  ([= playlist 
      :initializer list]   
   ))

(define (make-animator-module animator bone-root)
  (let ([identity (instantiate Transformation)])
    (with-access animator (Animator playlist)
      (letrec ([process (lambda (l dt)
                          (cond 
                            [(null? l)
                             '()]
                            [(pair? l)
                             (if (pair? (car l))
                                 (let* ([p (car l)]
                                        [anim (car p)]
                                        [info (cdr p)])
                                   (with-access info (PlayInfo time speed)
                                     (set! time (+ time (* dt speed)))
                                     (Animator-process time anim)
                                   (if (> time (Animation-duration anim))
                                       (set! time 0.)))
                                   (process (cdr l) dt))
                                 (error "Invalid object in animation playlist"))]
                            [else (error "Invalid animation playlist")]))])
        (lambda (dt) 
          ;; optimize by mutating list instead of generating new
          (if (pair? playlist)
              (begin
                (process playlist dt)
                (Animator-update-bones bone-root identity)
                )))))))

(define-generic (play animation (animator Animator))
  (with-access animator (Animator playlist)
    (set! playlist (cons (cons animation (instantiate PlayInfo)) playlist))))

(define-generic (play-speed-set! play-speed animation (animator Animator))
  (with-access animator (Animator playlist)
    (let ([entry (assoc animation playlist)])
      (if entry
          (with-access (cdr entry) (PlayInfo speed)
            (set! speed play-speed))))))

(define-generic (stop animation (animator Animator))
  (with-access animator (Animator playlist)
    (let ([entry (assoc animation playlist)])
      (if entry
          (set! playlist (remove entry playlist))))))

(define-generic (Animator-process time (animation Animation))
  (error "Unsupported animation object"))

(define-method (Animator-process time (animation ParallelAnimation))
  (with-access animation (ParallelAnimation child-animations)
    (map (lambda (child-anim) (Animator-process time child-anim))
         child-animations)))

;; ----- for old list-based animation keys -----
;; one can optimize by remembering car and cdr of first.
;; (define (find-first-and-last time key-list)
;;   (letrec ([visit (lambda (prev xs)
;;                     (if (pair? xs)
;;                         (if (> time (caar xs))
;;                             (visit (car xs) (cdr xs))
;;                             (cons prev (car xs)))
;;                         #f))])
;;     (if (pair? key-list)
;;         (visit (car key-list) (cdr key-list))
;;         #f)))


;; code duplication in next two functions ... fixme
(define (find-first-and-last-vec time keys)
  (let ([->time-vec-pair (lambda (i) 
                           (cons (vec-ref keys i) 
                                 (vec (vec-ref keys (+ i 1)) 
                                         (vec-ref keys (+ i 2))
                                         (vec-ref keys (+ i 3)))))]) 
    (letrec ([visit (lambda (i)
                      (if (< i (vec-length keys))
                          
                          (if (> time (vec-ref keys i))
                              (visit (+ i 4))
                              (cons (->time-vec-pair (- i 4))
                                    (->time-vec-pair i)))
                            #f))])
      (if keys 
          (visit 4) 
          #f))))

(define (find-first-and-last-quat time keys)
  (let ([->time-quat-pair (lambda (i) 
                           (cons (vec-ref keys i) 
                                 (quat
                                  (vec-ref keys (+ i 1)) 
                                  (vec-ref keys (+ i 2))
                                  (vec-ref keys (+ i 3))
                                  (vec-ref keys (+ i 4)))))])
    (letrec ([visit (lambda (i)
                      (if (< i (vec-length keys))
                          
                          (if (> time (vec-ref keys i))
                              (visit (+ i 5))
                              (cons (->time-quat-pair (- i 5))
                                    (->time-quat-pair i)))
                            #f))])
      (if keys 
          (visit 5) 
          #f))))

;; update transformation helper
(define (animate-transformation transformation time position-keys rotation-keys scaling-keys)
  (with-access transformation (Transformation translation rotation)
    (let ([p (find-first-and-last-vec time position-keys)]
          [r (find-first-and-last-quat time rotation-keys)])
      (if r
          (let ([first (car r)]
                [second (cdr r)])           
            (set! rotation 
                  (quat-interp 
                   (cdr first)  
                   (cdr second) 
                   (/ (- time (car first)) ;; time-scale
                      (- (car second) 
                         (car first)))))))
      (if p
          (let ([first (car p)]
                [second (cdr p)])
            (set! translation 
                  (vec-interp 
                   (cdr first)  ;; from-pos
                   (cdr second) ;; to-pos
                   (/ (- time (car first)) ;; time-scale
                      (- (car second) 
                         (car first))))))))))


(define-method (Animator-process time (animation TransformationAnimation))
  (with-access animation (TransformationAnimation 
                          transformation-node 
                          position-keys 
                          rotation-keys 
                          scaling-keys)
    (animate-transformation (TransformationNode-transformation transformation-node)
                            time 
                            position-keys
                            rotation-keys
                            scaling-keys)))

(define-method (Animator-process time (animation BoneAnimation))
  (with-access animation (BoneAnimation bone position-keys rotation-keys scaling-keys)
    (with-access bone (BoneNode dirty transformation)
      (animate-transformation transformation
                              time 
                              position-keys
                              rotation-keys
                              scaling-keys)
      (set! dirty #t))))

;; Q: do we include regular transformation nodes in bone accumulation?

;; (define-method (Animator-update-bones (node TransformationNode))
;;   (with-access node (TransformationNode transformation)
;;     (with-access transformation (Transformation translation rotation)
;;       (let* ([tos (car *bone-stack*)] ;; top of bone stack
;;              [push-trans (compose-trans tos transformation)])
;;         (set! *bone-stack* (cons push-trans *bone-stack*))
;;         (call-next-method)
;;         (set! *bone-stack* (cdr *bone-stack*))))))

(define-generic (Animator-update-bones (node Scene) tos)
  (error "Unsupported scene node"))

(define-method (Animator-update-bones (node SceneLeaf) tos)
  #f)

(define-method (Animator-update-bones (node SceneNode) tos)
  (do ([children (SceneNode-children node) (cdr children)])
      ((null? children))
    (Animator-update-bones (car children) tos)))

(define-method (Animator-update-bones (node BoneNode) tos)
  (with-access node (BoneNode transformation acc-transformation offset)
    (let ([push-trans (compose-trans tos transformation)])
      (compose-trans! push-trans offset acc-transformation)
      (with-access acc-transformation (Transformation translation rotation)
        (do ([children (SceneNode-children node) (cdr children)])
            ((null? children))
          (Animator-update-bones (car children) push-trans))))))
