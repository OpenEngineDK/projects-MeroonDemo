#!gsc-script

(define (scm? str)
  (and (> (string-length str) 4)
       (equal? ".scm"
               (substring str
                   (- (string-length str) 4)
                   (string-length str)))))

(let* ([args (cdr (command-line))]
       [target (car args)]
       [files  (cdr args)])
  ;;(display args)
  (let loop ([files files]
             [modules '()])
    (if (null? files)
        (link-flat (reverse modules)
                   output: target
                   warnings?: #f)
        (let ([file (car files)])
          (if (scm? file)
              (begin 
                (compile-file-to-c file #|options: '(debug)|#)
                (loop (cdr files)
                      (cons (substring file 0 (- (string-length file) 4))
                            modules)))
              (begin 
                (load file)
                (loop (cdr files) modules)))))))
