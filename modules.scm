(c-declare #<<c-declare-end
#include <Utils/Timer.h>
using namespace OpenEngine::Utils;
c-declare-end
)

;; get time in seconds ... maybe precision should be better.
(define time-in-seconds
  (c-lambda () float
#<<get-time-end
Time t = Timer::GetTime();
unsigned int usec = t.AsInt32();
___result = float(usec) * 1e-6;
get-time-end
))

(define make-modules list)

(define add-module cons)

(define (process-modules dt ms) 
  (map (lambda (f) (f dt)) ms))

(define (make-rotator rotatable delta-angle axis)
  (lambda (dt) 
    (rotate! rotatable (* delta-angle dt) axis)))

;; (define (slerp from to factor)
;;   (let ([cosom (+ (* (Quaternion-w from) (Quaternion-w to)) 
;;                   (* (Quaternion-x from) (Quaternion-x to))
;;                   (* (Quaternion-y from) (Quaternion-y to))
;;                   (* (Quaternion-z from) (Quaternion-z to)))]
;;         [target-w (Quaternion-w to)]
;;         [target-x (Quaternion-x to)]
;;         [target-y (Quaternion-y to)]
;;         [target-z (Quaternion-z to)])
;;     (if (< cosom 0.)
;;         (set! cosom (- cosom))
;;         (set! target-w (- target-w))
;;         (set! target-x (- target-x))
;;         (set! target-y (- target-y))
;;         (set! target-z (- target-z)))
;;     (if (> (- 1.0 cosom) 0.1) ;; epsilon 0.1
;;         (let* ([omega (acos cosom)]
;;                [sinom (sin omega)]
;;                [scale0 (/ (sin (* (- 1.0 factor) omega)) sinom)]
;;                [scale1 (/ (sin (* omega factor)) sinom)]

;; assume: 
;; target: Transformation
;; points: list of float x Transformation
;; further points is in ascending order by the first component (time-stamp);
(define (make-animator target points) 
  (let ([time 0.]
	[from-point (cons 0. target)]
	[to-point (car points)]
	[the-points (cdr points)])
    (lambda (dt)
      (set! time (+ time dt))
      (if (> time (car to-point))
	  (if (null? the-points)
	      (begin 
		(set! from-point (cons 0. target))
		(set! to-point (car points))
		(set! the-points (cdr points))
		(set! time 0.))
	      (begin 
		(set! from-point to-point)
		(set! to-point (car the-points))
		(set! the-points (cdr the-points))))
	  (let ([from-pos (Transformation-translation (cdr from-point))]
		[to-pos (Transformation-translation (cdr to-point))]
                [from-rot (Transformation-rotation (cdr from-point))]
                [to-rot (Transformation-rotation (cdr to-point))]
		[factor  (/ (- time (car from-point)) (- (car to-point) (car from-point)))])
	    (with-access target (Transformation translation rotation)
              (set! translation 
                    (vector 
                     (+ (vector-ref from-pos 0) (* factor (- (vector-ref to-pos 0) (vector-ref from-pos 0))))
                     (+ (vector-ref from-pos 1) (* factor (- (vector-ref to-pos 1) (vector-ref from-pos 1))))
                     (+ (vector-ref from-pos 2) (* factor (- (vector-ref to-pos 2) (vector-ref from-pos 2))))))

              (set! rotation 
                    ;;(slerp from-rot to-rot factor))
                    (instantiate Quaternion 
                        ;; try linear interpolation
                        :w (+ (* (- 1.0 factor) (Quaternion-w from-rot)) (* factor (Quaternion-w to-rot)))
                        :x (+ (* (- 1.0 factor) (Quaternion-x from-rot)) (* factor (Quaternion-x to-rot)))
                        :y (+ (* (- 1.0 factor) (Quaternion-y from-rot)) (* factor (Quaternion-y to-rot)))
                        :z (+ (* (- 1.0 factor) (Quaternion-z from-rot)) (* factor (Quaternion-z to-rot)))))
              (normalize! rotation))
            (update-transformation-pos! target)  
            (update-transformation-rot-and-scl! target))))))
