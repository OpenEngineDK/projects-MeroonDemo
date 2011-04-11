(c-declare #<<c-declare-end
#include <cstring>
#include <cstdio>
c-declare-end
)

;; The Transformation object describes a coordinate transformation in
;; three-dimensional space. This is done by means of a translation
;; vector, a scaling vector, a rotation quaternion, and a pivot
;; vector.

;; The pivot vector is used together with the quaternion to determine
;; the point of rotation. A rotation without a pivot point operates
;; around the local origo.

;; The four components are used to construct a 4x4 matrix describing
;; the combined transformation.
(define-class Transformation Object
  ([= translation 
      :initializer (lambda () (make-vector 3 0.0))]
   [= scaling
      :initializer (lambda () (make-vector 3 1.0))]
   [= rotation
      :initializer (lambda () (instantiate Quaternion))]
   [= pivot :initializer (lambda () #f)]))

;; some transformation operations (missing scale!!!)
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


;;; methods
(define-generic (Transformation-translate (o Transformation) x y z)
  (with-access o (Transformation translation)
    (set! translation (vector-map + translation (vector x y z)))))

(define-generic (Transformation-scale (o Transformation) x y z)
  (with-access o (Transformation scaling)
    (set! scaling (vector-map * scaling (vector x y z)))))

(define-generic (Transformation-rotate (o Transformation) angle vec)
  (with-access o (Transformation rotation)
    (set! rotation (quaternion* rotation (make-quaternion angle vec)))))

(define-method (show (o Transformation) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (with-access o (Transformation translation scaling rotation)
      (display "#<a Transformation: translation(" stream)
      (show translation stream)
      (display ") scaling(" stream)
      (show scaling stream)
      (display ") rotation(" stream)
      (show rotation stream)
      (display ")>" stream))))

;; define generic operations on transformations or anyting containing a transformation.
(define-generic (rotate! (o) angle vec)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " can not be rotated")))

;; (define-generic (translation-set! (o) x y z)
;;   (error (string-append "Object of type "
;;                         (->Class (object->class o))
;;                         " has no translation")))

;; (define-generic (rotation-set! (o) q)
;;   (error (string-append "Object of type "
;;                         (->Class (object->class o))
;;                         " has no rotation")))

;; (define-generic (scaling-set! (o) x y z)
;;   (error (string-append "Object of type "
;;                         (->Class (object->class o))
;;                         " has no scaling")))

(define-generic (translate! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not movable")))

(define-generic (scale! (o) x y z)
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " is not scalable")))

(define (uniform-scale! o s) 
  (scale! o s s s))

(define-method (rotate! (o Transformation) angle vec)
  (Transformation-rotate o angle vec))

(define-method (translate! (o Transformation) x y z)
  (Transformation-translate o x y z))

(define-method (scale! (o Transformation) x y z)
  (Transformation-scale o x y z))

;; (define-method (rotation-set! (o Transformation) q)
;;   (with-access o (Transformation rotation)
;;     (set! rotation q)))

;; (define-method (translation-set! (o Transformation) x y z)
;;   (with-access o (Transformation translation)
;;     (set! translation  (vector x y z))))

;; (define-method (scaling-set! (o Transformation) x y z)
;;   (with-access o (Transformation translation)
;;     (set! scaling (vector x y z))))
