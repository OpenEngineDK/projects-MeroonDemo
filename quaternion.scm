(define (make-quat)
  (vec 1. 0. 0. 0.))

(define (quat w x y z)
  (vec w x y z))

(define (quat? q) (and (vec? q) (fx= 4 (vec-length q))))
(define quat-deref vec-deref)
(define (quat-w q) (vec-ref q 0))
(define (quat-x q) (vec-ref q 1))
(define (quat-y q) (vec-ref q 2))
(define (quat-z q) (vec-ref q 3))

(define (quat-normalize! q)
  (let* ([norm-squared (vec-dot q q)])
    (if (fl<= norm-squared 0.0)
        (error "Can not normalize quat with zero norm")
        (vec-map fl/ q (make-vec 4 (flsqrt norm-squared))))))

(define (quat-conjugate q)
  (let ([c (vec-map - q)])
    (vec-set! c 0 (vec-ref q 0))
    c))

(define (rotate-vec v q)
  (let* ([q1 (quat 0. (vec-ref v 0) (vec-ref v 1) (vec-ref v 2))]
         [q2 (quat* (quat* q q1)
                          (quat-conjugate q))])
    (subvec q2 1 4)))

(define (make-quat-from-angle-axis angle v)
  (let* ([half-angle (fl* (exact->inexact angle) 0.5)]
         [q (vec-append
             (vec (cos half-angle))
             (vec-scalar* (sin half-angle) v))])
    (quat-normalize! q)
    q))

(define (make-quat-from-euler-angles x y z)
  (let ([cr (flcos (fl/ x 2.))]
        [cp (flcos (fl/ y 2.))]
        [cy (flcos (fl/ z 2.))]
        [sr (flsin (fl/ x 2.))]
        [sp (flsin (fl/ y 2.))]
        [sy (flsin (fl/ z 2.))])
    (let ([cpcy (fl* cp cy)]
          [spsy (fl* sp sy)])
      (vec
       (fl+ (fl* cr cpcy) (fl* sr spsy))
       (fl- (fl* sr cpcy) (fl* cr spsy))
       (fl+ (fl* cr sp cy) (fl* sr cp sy))
       (fl- (fl* cr cp sy) (fl* sr sp cy))))))

(define (make-quat-from-direction dir up)
  ;; very ugly implementation of quat-from-direction
  ;; taken directly from the c++ implementation.
  ;; need to schemify!
  (let ([biggest (lambda (x y z)
                   (let ([res x]
                         [i 0])
                     (if (> (vec-ref y 1) (vec-ref x 0))
                         (begin
                           (set! res y)
                           (set! i 1)))
                     (if (> (vec-ref z 2) (vec-ref res i))
                         (set! res z))
                     res))])
    (let* ([right (vec-cross dir up)]
           [trace (+ (vec-ref dir 0) (vec-ref up 1) (vec-ref right 2))])
      (if (> trace 0.)
          (let* ([sqtr (sqrt (+ trace 1.))]
                 [w (* .5 sqtr)]
                 [scale (/ .5 sqtr)]
                 [q (vec
                     w
                     (* (- (vec-ref up 2) (vec-ref right 1)) scale)
                     (* (- (vec-ref right 0) (vec-ref dir 2)) scale)
                     (* (- (vec-ref dir 1) (vec-ref up 0)) scale))])
            (quat-normalize! q)
            q)
          (let ([b (biggest dir up right)])
            (cond 
              [(eq? b dir)
               (let* ([s (sqrt (+ (- (vec-ref dir 0) (+ (vec-ref up 1) (vec-ref right 2))) 1.))]
                      [x (* .5 s)])
                 (if (not (eqv? s 0.0))
                     (set! s (/ .5 s)))
                 (let* ([w (* s (- (vec-ref up 2) (vec-ref right 1)))]
                        [y (* s (+ (vec-ref dir 1) (vec-ref up 0)))]
                        [z (* s (+ (vec-ref dir 2) (vec-ref right 0)))]
                        [q (vec w x y z)])
                   (quat-normalize! q)
                   q))]
              [(eq? b up)
               (let* ([s (sqrt (+ (- (vec-ref up 1) (+ (vec-ref right 2) (vec-ref dir 0))) 1.))]
                      [y (* .5 s)])
                 (if (not (eqv? s 0.0))
                     (set! s (/ .5 s)))
                 (let* ([w (* s (- (vec-ref right 0) (vec-ref dir 2)))]
                        [z (* s (+ (vec-ref up 2) (vec-ref right 1)))]
                        [x (* s (+ (vec-ref up 0) (vec-ref dir 1)))]
                        [q (vec w x y z)])
                   q))]
              [else
               (let* ([s (sqrt (+ (- (vec-ref right 2) (+ (vec-ref dir 0) (vec-ref up 1))) 1.))]
                      [z (* .5 s)])
                 (if (not (eqv? s 0.0))
                     (set! s (/ .5 s)))
                 (let* ([w (* s (- (vec-ref dir 1) (vec-ref up 0)))]
                        [x (* s (+ (vec-ref right 0) (vec-ref dir 2)))]
                        [y (* s (+ (vec-ref right 1) (vec-ref up 2)))]
                        [q (vec w x y z)])
                   (quat-normalize! q)
                   q))]))))))
 
(define (quat* p q)
  (let ([p0 (vec-ref p 0)]
        [p1 (vec-ref p 1)]
        [p2 (vec-ref p 2)]
        [p3 (vec-ref p 3)]
        [q0 (vec-ref q 0)]
        [q1 (vec-ref q 1)]
        [q2 (vec-ref q 2)]
        [q3 (vec-ref q 3)])
    (vec (fl- (fl* p0 q0)
                    (fl+ (fl* p1 q1)
                         (fl* p2 q2)
                         (fl* p3 q3)))
               (fl+ (fl- (fl* p2 q3)
                         (fl* p3 q2))
                    (fl* p0 q1)
                    (fl* p1 q0))
               (fl+ (fl- (fl* p3 q1)
                         (fl* p1 q3))
                    (fl* p0 q2)
                    (fl* p2 q0))
               (fl+ (fl- (fl* p1 q2)
                         (fl* p2 q1))
                    (fl* p0 q3)
                    (fl* p3 q0)))))

(define (quat-interp q1 q2 scale)
  (let ([q (vec+ (vec-scalar* (fl- 1.0 scale) q1)
                       (vec-scalar*          scale  q2))])
    (quat-normalize! q)
    q))
