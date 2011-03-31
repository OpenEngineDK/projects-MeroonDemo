;; an animated mesh is a Mesh which contains a list of the bones that affect it.
(define-class AnimatedMesh Mesh
  ([= bind-pose-vertices ;; the original "bind pose" mesh data 
     :immutable]
   [= bind-pose-normals 
      :immutable]
   [= bones ;; bones that affect this mesh
      :immutable :initializer list]
   ))

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
      :initialiser vector]
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
                                        [time (+ (cdr p) dt)]
                                        [anim (car p)])
                                   (Animator-process time anim)
                                   (if (> time (Animation-duration anim))
                                       (set-cdr! p 0.)
                                       (set-cdr! p time))
                                   (process (cdr l) dt))
                                 (error "Invalid object in animation playlist"))]
                            [(error "Invalid animation playlist")]))])
        (lambda (dt) 
          ;; optimize by mutating list instead of generating new
          (if (pair? playlist)
              (begin
                (process playlist dt)
                (Animator-update-bones bone-root identity)
                )))))))

(define-generic (play animation (animator Animator))
  (with-access animator (Animator playlist)
    (set! playlist (cons (cons animation 0.) playlist))))

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
                           (cons (f32vector-ref keys i) 
                                 (vector (f32vector-ref keys (+ i 1)) 
                                         (f32vector-ref keys (+ i 2))
                                         (f32vector-ref keys (+ i 3)))))]) 
    (letrec ([visit (lambda (i)
                      (if (< i (f32vector-length keys))
                          
                          (if (> time (f32vector-ref keys i))
                              (visit (+ i 4))
                              (cons (->time-vec-pair (- i 4))
                                    (->time-vec-pair i)))
                            #f))])
      (if keys 
          (visit 4) 
          #f))))

(define (find-first-and-last-quat time keys)
  (let ([->time-quat-pair (lambda (i) 
                           (cons (f32vector-ref keys i) 
                                 (instantiate Quaternion 
                                     :w (f32vector-ref keys (+ i 1)) 
                                     :x (f32vector-ref keys (+ i 2))
                                     :y (f32vector-ref keys (+ i 3))
                                     :z (f32vector-ref keys (+ i 4)))))])
    (letrec ([visit (lambda (i)
                      (if (< i (f32vector-length keys))
                          
                          (if (> time (f32vector-ref keys i))
                              (visit (+ i 5))
                              (cons (->time-quat-pair (- i 5))
                                    (->time-quat-pair i)))
                            #f))])
      (if keys 
          (visit 5) 
          #f))))


;; linear interpolation functions should be placed in ... math?
(define (vector-interp v1 v2 scale)
  (let ([x (vector-ref v1 0)]
        [y (vector-ref v1 1)]
        [z (vector-ref v1 2)])
    (vector (+ x (* scale (- (vector-ref v2 0) x)))
            (+ y (* scale (- (vector-ref v2 1) y)))
            (+ z (* scale (- (vector-ref v2 2) z))))))

(define (quaternion-interp q1 q2 scale)
  (instantiate Quaternion 
      :w (+ (* (- 1.0 scale) (Quaternion-w q1)) (* scale (Quaternion-w q2)))
      :x (+ (* (- 1.0 scale) (Quaternion-x q1)) (* scale (Quaternion-x q2)))
      :y (+ (* (- 1.0 scale) (Quaternion-y q1)) (* scale (Quaternion-y q2)))
      :z (+ (* (- 1.0 scale) (Quaternion-z q1)) (* scale (Quaternion-z q2)))))


;; update transformation helper
(define (animate-transformation transformation time position-keys rotation-keys scaling-keys)
  (with-access transformation (Transformation translation rotation)
    (let ([p (find-first-and-last-vec time position-keys)]
          [r (find-first-and-last-quat time rotation-keys)])
      (if r
          (let ([first (car r)]
                [second (cdr r)])           
            (set! rotation 
                  (quaternion-interp 
                   (cdr first)  
                   (cdr second) 
                   (/ (- time (car first)) ;; time-scale
                      (- (car second) 
                         (car first)))))
            (update-c-matrix! rotation))
          (update-transformation-rot-and-scl! transformation))
      (if p
          (let ([first (car p)]
                [second (cdr p)])
            (set! translation 
                  (vector-interp 
                   (cdr first)  ;; from-pos
                   (cdr second) ;; to-pos
                   (/ (- time (car first)) ;; time-scale
                      (- (car second) 
                         (car first)))))
            (update-transformation-pos! transformation))))))


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

(define (compose-trans t1 t2)
  (with-access t1 (Transformation rotation)
    (instantiate Transformation 
        :translation (vector-map 
                      +
                      (rotate-vector 
                       (Transformation-translation t2) 
                       rotation)
                      (Transformation-translation t1))
        :rotation (quaternion*                 
                   rotation
                   (Transformation-rotation t2)))))

(define (compose-trans! t1 t2 t3)
  (with-access t3 (Transformation translation rotation)
    (set! translation (vector-map 
                       +
                       (rotate-vector 
                        (Transformation-translation t2) 
                        (Transformation-rotation t1))
                       (Transformation-translation t1)))
    (set! rotation (quaternion*                 
                    (Transformation-rotation t1)
                    (Transformation-rotation t2)))))

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
        (update-c-matrix! rotation)
        (update-transformation-rot-and-scl! acc-transformation)
        (update-transformation-pos! acc-transformation)
        (do ([children (SceneNode-children node) (cdr children)])
            ((null? children))
          (Animator-update-bones (car children) push-trans))))))
