(define-class Boid Object
  ([= velocity :initializer (lambda () (vec 0. 0. 0.))]
   [= accel :initializer (lambda () (vec 0. 0. 0.))]))

(define (make-boids-module transformation animation animator)
  (let ([boid (instantiate Boid)]
        [center-point (vec 0. 200. -300.)])
    (with-access transformation (Transformation translation rotation)
      (lambda (dt) 
        (with-access boid (Boid velocity accel)
          (set! accel (vec 0. 0. 0.))
          (cohersion-rule translation boid center-point)
          (random-dir-rule translation boid)

          (set! velocity (vec-scalar* 0.98 (vec+ velocity (vec-scalar* (* 0.5 dt dt) accel))))
          (set! translation (vec+ translation (vec-scalar* dt velocity)))
          
          (let ([speed (vec-norm velocity)])
            ;; (display "play speed: ")
            ;; (display (* speed .09))
            ;; (newline)
            (play-speed-set! (* speed .1) animation animator) 
            (if (> speed 1.0)
                (let* ([x (vec-normalize velocity)]
                       [z (vec-normalize (vec-cross x (vec 0. 1. 0.)))]
                       [y (vec-normalize (vec-cross z x))])
                  (set! rotation (quat-interp 
                                  rotation 
                                  (make-quat-from-direction x y)
                                  (* 0.1 speed dt)))))))))))

(define (cohersion-rule pos boid center-point)
  (with-access boid (Boid accel)
    (set! accel (vec+ 
                 accel 
                 (vec-scalar* 
                  50.0 
                  (vec- 
                   center-point 
                   pos))))))

(define (random-dir-rule pos boid)
  (with-access boid (Boid velocity)
    (let ([dir (vec-scalar* 
                 1.5
                 (vec
                  (- (* 2. (random-real)) 1.)
                  (- (* 2. (random-real)) 1.)
                  (- (* 2. (random-real)) 1.)))])
      (if (> (vec-dot dir velocity) .1)
          (set! velocity (vec+ 
                          velocity
                          dir
                          ))))))

;; boids using bullet!
(define (make-bullet-boids-module physics rigid-body animation animator)
  (with-access rigid-body (RigidBody transformation)
    (with-access transformation (Transformation rotation)
      (linear-damping-set! physics rigid-body 0.6)
      (let ([center-point (vec 0. 0. 300.)])
        (lambda (dt) 
          (bullet-cohersion-rule physics rigid-body center-point)
          (bullet-random-dir-rule physics rigid-body)
          (let ([velocity (linear-velocity physics rigid-body)])
            (let ([speed (vec-norm velocity)])
              (play-speed-set! (* 0.01 speed) animation animator)
              (if (> speed 1.0)
                  (let* ([x (vec-normalize velocity)]
                         [z (vec-normalize (vec-cross x (vec 0. 1. 0.)))]
                         [y (vec-normalize (vec-cross z x))])
                    (set! rotation (quat-interp 
                                    rotation 
                                    (make-quat-from-direction x y)
                                    (* 0.1 speed dt)))
                    ;;(synchronize-transform! physics rb)
                    )))))))))

(define (bullet-cohersion-rule physics rb center-point)
  (with-access rb (RigidBody transformation)
    (with-access transformation (Transformation translation rotation)
      (let ([force (vec-scalar* 
                    5. 
                    (vec- 
                     center-point 
                     translation))]
          [rel-pos (rotate-vec (vec 0. 0. -2.) rotation)])
      (apply-force-relative! physics 
                   rb 
                   force
                   rel-pos)))))

(define (bullet-random-dir-rule physics rb)
    (let ([velocity (linear-velocity physics rb)]
          [dir (vec-scalar* 
                10.5
                (vec
                 (- (* 2. (random-real)) 1.)
                 (- (* 2. (random-real)) 1.)
                 (- (* 2. (random-real)) 1.)))])
    (if (> (vec-dot dir velocity) .1)
        (linear-velocity-set! physics 
                              rb 
                              (vec+ 
                               velocity
                               dir
                               )))))