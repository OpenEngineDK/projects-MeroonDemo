(define *dot-node-ids* '())

(define (node-id node)
  (cond
    [(assoc node *dot-node-ids*)
     => (lambda (p) (cdr p))]
    [else 
     (let ([id (symbol->string (gensym))])
       (set! *dot-node-ids* 
             (cons (cons node id)
                   *dot-node-ids*))
       id)]))

(define (dot-class-name node options . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (display "{ " stream)
    (display (node-id node) stream)
    (display " [label=\"" stream)
    (display (Class-name (object->class node)) stream)
    (display "\\n" stream)
    (if (Scene? node)
        (begin
          (if (Scene-name node)
              (begin
                (display (Scene-name node) stream)
                (display "\\n" stream)))
          (if (Scene-info node)
              (begin
                (display (Scene-info node) stream)
                (display "\\n" stream)))))
    (do ([option options (cdr option)])
        ((null? option))
      (display (car option) stream)
      (display "\\n" stream))
    (display "\"]}" stream)))
  
(define-generic (dot-visit (node Object) . stream)
  (error "Unsupported scene node"))

(define-method (dot-visit (node Scene) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))]) 
    (dot-class-name node '() stream)
    (display ";\n" stream)))
  
(define-method (dot-visit (node SceneParent) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))])
    (dot-class-name node '() stream)
    (with-access node (SceneParent children)
      (if (> (length children) 0)
          (begin
            (display " -> { " stream)
            (map (lambda (child)
                   (display (node-id child) stream)
                   (display "; " stream))
                 children)
            (display "} " stream)))
      (display ";\n" stream))
    (do ([children (SceneParent-children node) (cdr children)])
        ((null? children))
      (dot-visit (car children) stream))))

(define-method (dot-visit (node MeshNode) . stream)
  (let ([stream (if (pair? stream) (car stream) (current-output-port))]) 
    (let ([mesh (MeshNode-mesh node)])
      (dot-class-name node (list (Class-name (object->class mesh))) stream)
      (if (AnimatedMesh? mesh)
          (begin 
            (display " -> { " stream)
            (map (lambda (bone)
                   (display (node-id bone) stream)
                   (display "; " stream))
                 (AnimatedMesh-bones mesh))
            (display "} [color=red]" stream)))
      (display ";\n" stream))))

(define (->dot node filepath)
  (let ([stream (open-output-file filepath)])
    (display "digraph {\n" stream)
    (dot-visit node stream)
    (display "}\n" stream)
    (close-output-port stream)))

