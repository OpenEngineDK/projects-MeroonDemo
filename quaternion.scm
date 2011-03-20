(c-declare #<<c-declare-end
#include <cstring>
c-declare-end
)
(c-define-type FloatArray (pointer "float"))

(define-class Quaternion Object
  ([= w  :initializer (lambda () 1.0)]
   [= x  :initializer (lambda () 0.0)]
   [= y  :initializer (lambda () 0.0)]
   [= z  :initializer (lambda () 0.0)]
   [= c-matrix :immutable 
      :initializer (c-lambda () FloatArray
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
	           ((c-lambda (FloatArray) void
		      "delete[] ___arg1;")
		   c-matrix))))
  (call-next-method))

     ;; :initializer (lambda ()

       ;; 		    c-lambda () FloatArray
      ;; 		     "float* m = new float[9];
      ;;                memset(m, 0x0, sizeof(float) * 9); 
      ;;                m[0]  = 1.0f;
      ;;                m[4]  = 1.0f;
      ;;                m[8] = 1.0f;
      ;; 		     ___result_voidstar = m;"
      ;; 		     )]))


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
  ((c-lambda (float float float float FloatArray) void
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
  (if (Quaternion? q)
      (instantiate Quaternion 
        :w (Quaternion-w q) 
        :x (- (Quaternion-x q))
        :y (- (Quaternion-y q))
        :z (- (Quaternion-z q)))
      (error "Attempt to calculate conjugate of non-quaternion")))


(define (mk-Quaternion angle vec)
    (let* ([half-angle (* angle 0.5)]
           [q (instantiate Quaternion 
                :w (cos half-angle)
                :x (* (sin half-angle) (vector-ref vec 0))
                :y (* (sin half-angle) (vector-ref vec 1))
                :z (* (sin half-angle) (vector-ref vec 2)))])
      (normalize! q)
      q))

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
