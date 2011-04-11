#!gsc-script

(define (scm? str)
  (and (> (string-length str) 4)
       (equal? ".scm"
               (substring str
                   (- (string-length str) 4)
                   (string-length str)))))

(let* ([args (cdr (command-line))]
       [link   (car  args)]
       [target (cadr args)]
       [files  (cddr args)])
  ;;(display args)
  (let loop ([files files]
             [modules '()])
    (if (null? files)
        (link-incremental (reverse modules)
                          output: target
                          base: link)
        (let ([file (car files)])
          (if (scm? file)
              (begin 
                (compile-file-to-c file options: '(debug track-scheme))
                (loop (cdr files)
                      (cons (substring file 0 (- (string-length file) 4))
                            modules)))
              (begin 
                (load file)
                (loop (cdr files) modules)))))))
