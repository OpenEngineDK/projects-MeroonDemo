(c-declare #<<c-declare-end
#include <cstring>
c-declare-end
)
    
(define-class Quaternion Object
  ([= w  :initializer (lambda () 1.0)]
   [= x  :initializer (lambda () 0.0)]
   [= y  :initializer (lambda () 0.0)]
   [= z  :initializer (lambda () 0.0)]))

;; Quaternion constructors:
;;   (make-quaternion real)
;;   (make-quaternion real image1 image2 image3)
;;   (make-quaternion x-angle y-angle z-angle)    euler angles
;;   (make-quaternion angle axis)                 angle + axis vector
(define (make-quaternion #!rest args)
  (let ([len (length args)])
    (cond
      [(fx= len 1)
       (instantiate Quaternion :w (car args))]
      [(fx= len 2)
       (apply make-quaternion-from-angle-axis args)]
      [(fx= len 3)
       (apply make-quaternion-from-euler-angles args)]
      [(fx= len 4)
       (instantiate Quaternion
         :w (list-ref args 0)
         :x (list-ref args 1)
         :y (list-ref args 2)
         :z (list-ref args 3))]
      [else
       (error "invalid arguments to make-quaternion")])))

(define (quaternion-normalize! q)
 (let* ([w (Quaternion-w q)]
         [x (Quaternion-x q)]
         [y (Quaternion-y q)]
         [z (Quaternion-z q)]
         [norm-squared (+ (* w w) (* x x) (* y y) (* z z))])
    (if (> norm-squared 0.0)
        (let ([norm (sqrt norm-squared)])
          (with-access q (Quaternion w x y z)
              (set! w (/ w norm))
              (set! x (/ x norm))
              (set! y (/ y norm))
              (set! z (/ z norm))))
        (error "Can not normalize quaternion with zero norm"))))

(define (make-conjugate q) 
      (instantiate Quaternion 
        :w (Quaternion-w q) 
        :x (- (Quaternion-x q))
        :y (- (Quaternion-y q))
        :z (- (Quaternion-z q))))

(define (rotate-vector vec q)
  (let ([q1 (quaternion* 
             (quaternion* 
              q
              (instantiate Quaternion
                  :x (vector-ref vec 0)
                  :y (vector-ref vec 1)
                  :z (vector-ref vec 2)))
              (make-conjugate q))])
    (vector (Quaternion-x q1) (Quaternion-y q1) (Quaternion-z q1))))

(define (make-quaternion-from-angle-axis angle vec)
    (let* ([half-angle (* angle 0.5)]
           [q (instantiate Quaternion 
                :w (cos half-angle)
                :x (* (sin half-angle) (vector-ref vec 0))
                :y (* (sin half-angle) (vector-ref vec 1))
                :z (* (sin half-angle) (vector-ref vec 2)))])
      (quaternion-normalize! q)
      q))

(define (make-quaternion-from-euler-angles x y z)
  (let ([cr (cos (/ x 2))]
        [cp (cos (/ y 2))]
        [cy (cos (/ z 2))]
        [sr (sin (/ x 2))]
        [sp (sin (/ y 2))]
        [sy (sin (/ z 2))])
    (let ([cpcy (* cp cy)]
          [spsy (* sp sy)])
      (instantiate Quaternion
        :w (+ (* cr cpcy) (* sr spsy))
        :x (- (* sr cpcy) (* cr spsy))
        :y (+ (* cr sp cy) (* sr cp sy))
        :z (- (* cr cp sy) (* sr sp cy))))))


;; very ugly implementation of quaternion-from-direction
;; taken directly from the c++ implementation.
;; need to schemify!
(define (biggest x y z)
  (let ([res x]
        [i 0])
    (if (> (vector-ref y 1) (vector-ref x 0))
        (begin
          (set! res y)
          (set! i 1)))
    (if (> (vector-ref z 2) (vector-ref res i))
        (set! res z))
    res))

(define (make-quaternion-from-direction dir up)
  (let* ([right (vector-cross dir up)]
         [trace (+ (vector-ref dir 0) (vector-ref up 1) (vector-ref right 2))])
    (if (> trace 0.)
        (let* ([sqtr (sqrt (+ trace 1.))]
               [w (* .5 sqtr)]
               [scale (/ .5 sqtr)]
               [q (instantiate Quaternion 
                      :w w
                      :x (* (- (vector-ref up 2) (vector-ref right 1)) scale)
                      :y (* (- (vector-ref right 0) (vector-ref dir 2)) scale)
                      :z (* (- (vector-ref dir 1) (vector-ref up 0)) scale))])
          (quaternion-normalize! q)
          q)
        (let ([b (biggest dir up right)])
          (cond 
            [(eq? b dir)
             (let* ([s (sqrt (+ (- (vector-ref dir 0) (+ (vector-ref up 1) (vector-ref right 2))) 1.))]
                    [x (* .5 s)])
               (if (not (eqv? s 0.0))
                   (set! s (/ .5 s)))
               (let* ([w (* s (- (vector-ref up 2) (vector-ref right 1)))]
                      [y (* s (+ (vector-ref dir 1) (vector-ref up 0)))]
                      [z (* s (+ (vector-ref dir 2) (vector-ref right 0)))]
                      [q (instantiate Quaternion :w w :x x :y y :z z)])
                 (quaternion-normalize! q)
                 q))]
            [(eq? b up)
             (let* ([s (sqrt (+ (- (vector-ref up 1) (+ (vector-ref right 2) (vector-ref dir 0))) 1.))]
                    [y (* .5 s)])
               (if (not (eqv? s 0.0))
                   (set! s (/ .5 s)))
               (let* ([w (* s (- (vector-ref right 0) (vector-ref dir 2)))]
                      [z (* s (+ (vector-ref up 2) (vector-ref right 1)))]
                      [x (* s (+ (vector-ref up 0) (vector-ref dir 1)))]
                      [q (instantiate Quaternion :w w :x x :y y :z z)])
                 q))]
            [else
             (let* ([s (sqrt (+ (- (vector-ref right 2) (+ (vector-ref dir 0) (vector-ref up 1))) 1.))]
                    [z (* .5 s)])
               (if (not (eqv? s 0.0))
                   (set! s (/ .5 s)))
               (let* ([w (* s (- (vector-ref dir 1) (vector-ref up 0)))]
                      [x (* s (+ (vector-ref right 0) (vector-ref dir 2)))]
                      [y (* s (+ (vector-ref right 1) (vector-ref up 2)))]
                      [q (instantiate Quaternion :w w :x x :y y :z z)])
                 (quaternion-normalize! q)
                 q))])))))
 
(define (quaternion* q1 q2)
  (instantiate Quaternion 
    :w (- 
        (* (Quaternion-w q1) (Quaternion-w q2)) 
        (+ 
         (* (Quaternion-x q1) (Quaternion-x q2))  
         (* (Quaternion-y q1) (Quaternion-y q2))
         (* (Quaternion-z q1) (Quaternion-z q2))))
    :x (+ 
        (- 
         (* (Quaternion-y q1) (Quaternion-z q2))
         (* (Quaternion-z q1) (Quaternion-y q2)))
        (* (Quaternion-w q1) (Quaternion-x q2))
        (* (Quaternion-w q2) (Quaternion-x q1)))
    :y (+ 
        (- 
         (* (Quaternion-z q1) (Quaternion-x q2))
         (* (Quaternion-x q1) (Quaternion-z q2)))
        (* (Quaternion-w q1) (Quaternion-y q2))
        (* (Quaternion-w q2) (Quaternion-y q1)))
    :z (+ 
        (- 
         (* (Quaternion-x q1) (Quaternion-y q2))
         (* (Quaternion-y q1) (Quaternion-x q2)))
        (* (Quaternion-w q1) (Quaternion-z q2))
        (* (Quaternion-w q2) (Quaternion-z q1)))))

(define (quaternion-interp q1 q2 scale)
  (let ([q (instantiate Quaternion
              :w (+ (* (- 1.0 scale) (Quaternion-w q1)) (* scale (Quaternion-w q2)))
              :x (+ (* (- 1.0 scale) (Quaternion-x q1)) (* scale (Quaternion-x q2)))
              :y (+ (* (- 1.0 scale) (Quaternion-y q1)) (* scale (Quaternion-y q2)))
              :z (+ (* (- 1.0 scale) (Quaternion-z q1)) (* scale (Quaternion-z q2))))])
    (quaternion-normalize! q)
    q))

(define-method (show (o Quaternion) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (with-access o (Quaternion w x y z)
      (display "#<a Quaternion: w(" stream)
      (show w stream)
      (display ") x(" stream)
      (show x stream)
      (display ") y(" stream)
      (show y stream)
      (display ") z(" stream)
      (show z stream)
      (display ")>" stream))))
