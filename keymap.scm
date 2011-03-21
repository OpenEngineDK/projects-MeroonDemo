;; Key mapping

(define (keymap-make . rest) ;; TODO, use parent from optional arg
  (box (list)))


(define (keymap-set-key mapb key fn)
  (set-box! mapb (cons (cons key fn) (unbox mapb))))

(define (keymap-handle mapb key)
  (let* ([map (unbox mapb)]
         [recv (assoc key map)])
    (if recv
        ((cdr recv))
        (begin
          (display "Unbound key: ")
          (display key)
          (newline)))))

