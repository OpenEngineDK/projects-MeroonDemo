;; -o : output file
;; -S : sources
;; -I : includes
;; -L : loads
;; -l : link file
;; -D : enable declares
;; -d : disable declares
(define (parse args)
  (let loop ([args args]
             [state 'S]
             [target #f]
             [link #f]
             [loads '()]
             [incs '()]
             [files '()]
             [enabled '()]
             [disabled '()])
    (if (null? args)
        (values target link (reverse loads) (reverse incs) (reverse files) enabled disabled)
        (let ([arg (car args)]
              [args (cdr args)])
          ;; (pp (list state arg))
          ;; (newline)
          (if (equal? (substring arg 0 1) "-")
              (loop args (string->symbol (substring arg 1 2))
                    target link loads incs files enabled disabled)
              (case state
                [(o) (loop args state    arg link loads incs files enabled disabled)]
                [(l) (loop args state target  arg loads incs files enabled disabled)]
                [(L) (loop args state target link (cons arg loads) incs files enabled disabled)]
                [(I) (loop args state target link loads (cons arg incs) files enabled disabled)]
                [(S) (loop args state target link loads incs (cons arg files) enabled disabled)]
                [(D) (loop args state target link loads incs files (cons arg enabled) disabled)]
                [(d) (loop args state target link loads incs files enabled (cons arg disabled))]
                [else (error "Unknown parse state or flag: " state)]))))))

(define (files->modules files)
  (map (lambda (f) (substring f 0 (- (string-length f) 4))) files))

(define (scm? str)
  (and (> (string-length str) 4)
       (equal? ".scm"
               (substring str
                   (- (string-length str) 4)
                   (string-length str)))))
