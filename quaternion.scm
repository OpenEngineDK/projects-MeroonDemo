(c-declare #<<c-declare-end
#include <cstring>
c-declare-end
)
    
(define-class Quaternion Object
  ([= w  :initializer (lambda () 1.0)]
   [= x  :initializer (lambda () 0.0)]
   [= y  :initializer (lambda () 0.0)]
   [= z  :initializer (lambda () 0.0)]
   [= c-matrix :immutable 
      :initializer (c-lambda () (pointer float)
		     "float* m = new float[9];
                      memset(m, 0x0, sizeof(float) * 9); 
                      m[0]  = 1.0f;
                      m[4]  = 1.0f;
                      m[8] = 1.0f;
       		      ___result_voidstar = m;")]))

(define-method (initialize! (o Quaternion))
  ;; free the c-matrix when object is reclaimed by the gc.
  (make-will o (lambda (x) 
   		 ;; (display "delete array\n")
		 (with-access x (Quaternion c-matrix)
	           ((c-lambda ((pointer float)) void
		      "delete[] ___arg1;")
                    c-matrix))))
  (call-next-method))

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

(define-generic (normalize! (o))
  (error (string-append "Object of type "
                        (->Class (object->class o))
                        " can not be normalized")))

(define-method (normalize! (o Quaternion))
  (let* ([w (Quaternion-w o)]
         [x (Quaternion-x o)]
         [y (Quaternion-y o)]
         [z (Quaternion-z o)]
         [norm-squared (+ (* w w) (* x x) (* y y) (* z z))])
    (if (> norm-squared 0.0)
        (let ([norm (sqrt norm-squared)])
          (with-access o (Quaternion w x y z)
              (set! w (/ w norm))
              (set! x (/ x norm))
              (set! y (/ y norm))
              (set! z (/ z norm)))
          (update-c-matrix! o))
        (error "Can not normalize quaternion with zero norm"))))

(define (update-c-matrix! q)
  ((c-lambda (float float float float (pointer float)) void
#<<UPDATE_C_MATRIX_END
float w  = ___arg1;
float x  = ___arg2;
float y  = ___arg3;
float z  = ___arg4;
float* m = ___arg5;

// first column
m[0] = 1-2*y*y-2*z*z;
m[1] = 2*x*y+2*w*z;
m[2] = 2*x*z-2*w*y;

// second column
m[3] = 2*x*y-2*w*z;
m[4] = 1-2*x*x-2*z*z;
m[5] = 2*y*z+2*w*x;

// third column
m[6] = 2*x*z+2*w*y;
m[7] = 2*y*z-2*w*x;
m[8] = 1-2*x*x-2*y*y;

UPDATE_C_MATRIX_END
)
   (Quaternion-w q)
   (Quaternion-x q)
   (Quaternion-y q)
   (Quaternion-z q)
   (Quaternion-c-matrix q)))

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
      (normalize! q)
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
