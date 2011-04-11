(define-class Boid Object
  ([= velocity :initializer (lambda () (vector 0. 0. 0.))]
   [= accel :initializer (lambda () (vector 0. 0. 0.))]))

(define (make-boids-module transformation animation animator)
  (let ([boid (instantiate Boid)]
        [center-point (vector 0. 200. 300.)])
    (with-access transformation (Transformation translation rotation)
      (lambda (dt) 
        (with-access boid (Boid velocity accel)
          (set! accel (vector 0. 0. 0.))
          (cohersion-rule translation boid center-point)
          (random-dir-rule translation boid)

          (set! velocity (vector-scalar* 0.98 (vector+ velocity (vector-scalar* (* 0.5 dt dt) accel))))
          (set! translation (vector+ translation (vector-scalar* dt velocity)))
          
          (let ([speed (vector-norm velocity)])
            ;; (display "play speed: ")
            ;; (display (* speed .09))
            ;; (newline)
            (play-speed-set! (* speed .1) animation animator) 
            (if (> speed 1.0)
                (let* ([x (vector-normalize velocity)]
                       [z (vector-normalize (vector-cross x (vector 0. 1. 0.)))]
                       [y (vector-normalize (vector-cross z x))])
                  (set! rotation (quaternion-interp 
                                  rotation 
                                  (make-quaternion-from-direction x y)
                                  (* 0.1 speed dt)))))
            ))))))

(define (cohersion-rule pos boid center-point)
  (with-access boid (Boid accel)
    (set! accel (vector+ 
                 accel 
                 (vector-scalar* 
                  50.0 
                  (vector- 
                   center-point 
                   pos))))))


(define (random-dir-rule pos boid)
  (with-access boid (Boid velocity)
    (let ([dir (vector-scalar* 
                 1.5
                 (vector
                  (- (* 2. (random-real)) 1.)
                  (- (* 2. (random-real)) 1.)
                  (- (* 2. (random-real)) 1.)))])
      (if (> (vector-dot dir velocity) .1)
          (set! velocity (vector+ 
                          velocity
                          dir
                          ))))))



;; boids using bullet!

(define (make-bullet-boids-module physics rigid-body animation animator)
  (with-access rigid-body (RigidBody transformation)
    (with-access transformation (Transformation rotation)
      (linear-damping-set! physics rigid-body 0.6)
      (let ([center-point (vector 0. 0. 300.)])
        (lambda (dt) 
          (bullet-cohersion-rule physics rigid-body center-point)
          (bullet-random-dir-rule physics rigid-body)
          (let ([velocity (linear-velocity physics rigid-body)])
            (let ([speed (vector-norm velocity)])
              ;; (display "speed: ")
              ;; (display speed)
              ;; (newline)
              (play-speed-set! (* 0.01 speed) animation animator)
              (if (> speed 1.0)
                  (let* ([x (vector-normalize velocity)]
                         [z (vector-normalize (vector-cross x (vector 0. 1. 0.)))]
                         [y (vector-normalize (vector-cross z x))])
                    (set! rotation (quaternion-interp 
                                    rotation 
                                    (make-quaternion-from-direction x y)
                                    (* 0.1 speed dt)))
                    ;;(synchronize-transform! physics rb)
                    )))))))))

(define (bullet-cohersion-rule physics rb center-point)
  (with-access rb (RigidBody transformation)
    (with-access transformation (Transformation translation rotation)
      (let ([force (vector-scalar* 
                    5. 
                    (vector- 
                     center-point 
                     translation))]
          [rel-pos (rotate-vector (vector 0. 0. -2.) rotation)])
      (apply-force-relative! physics 
                   rb 
                   force
                   rel-pos)))))

(define (bullet-random-dir-rule physics rb)
    (let ([velocity (linear-velocity physics rb)]
          [dir (vector-scalar* 
                10.5
                (vector
                 (- (* 2. (random-real)) 1.)
                 (- (* 2. (random-real)) 1.)
                 (- (* 2. (random-real)) 1.)))])
    (if (> (vector-dot dir velocity) .1)
        (linear-velocity-set! physics 
                              rb 
                              (vector+ 
                               velocity
                               dir
                               )))))