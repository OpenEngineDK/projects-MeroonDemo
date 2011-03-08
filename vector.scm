(define (vector-map f fst . rest)
  (letrec ([len (vector-length fst)]
	   [check-length (lambda (vs)
			   (if (null? vs)
			       #t
			       (if (= len (vector-length (car vs)))
				   (check-length (cdr vs))
				   (error "Invalid vector length"))))])
    (check-length rest)
    (letrec ([result (make-vector len)]
	     [args (lambda (i vs)
		     (if (null? vs)
			 '()
			 (cons (vector-ref (car vs) i)
			       (args i (cdr vs)))))]
	     [visit (lambda (i)
		      (if (= i len)
			  result
			  (begin
			    (vector-set! result i
					 (apply f (args i (cons fst rest))))
			    (visit (+ i 1)))))])
      (visit 0))))
