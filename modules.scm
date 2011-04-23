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


