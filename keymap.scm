;; Key mapping

(define (keymap-make . rest) ;; TODO, use parent from optional arg
  (box (list)))


(define (keymap-add-key! mapb key fn)
  (letrec ( [helper (lambda (k fun)
                     (let* ([kmap (unbox mapb)]
                            [recv (assoc k kmap)])
                       (if recv
                           (map (lambda (old)
                                  (if (equal? (car old) k)
                                      (cons k (cons fun (cdr old)))
                                      old)) kmap)
                           (cons (cons k (list fun)) kmap))))])
  (if (list? key)
      (map (lambda (k)
             (set-box! mapb (helper k fn)))
           key)
      (set-box! mapb (helper key fn)))))

(define (keymap-run-recv receivers key state)
  (do ([recvs receivers (cdr recvs)])
       ((null? recvs))
    ((car recvs) key state)))

(define (keymap-handle mapb key state)
  (let* ([map (unbox mapb)]
         [recv (assoc key map)]
         [anyrecv (assoc 'any map)])
    (if anyrecv
        (keymap-run-recv (cdr anyrecv) key state))
    (if recv
        (keymap-run-recv (cdr recv) key state))))


