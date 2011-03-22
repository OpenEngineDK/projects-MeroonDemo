(define (queue-next? q)
  (pair? (unbox q)))

(define (queue-push q fn)
  (set-box! q (cons fn (unbox q))))

(define (queue-pop q)
  (let ([n (car (unbox q))])
    (set-box! q (cdr (unbox q)))
    n))

(define (queue-run q)
  (letrec ([loop
            (lambda ()
              (if (queue-next? q)
                  (begin ((queue-pop q))
                         loop)))])
    (loop)))
