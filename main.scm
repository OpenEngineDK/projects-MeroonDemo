(let* ([mesh (instantiate MeshNode
                :geotype 'triangles
                :datablocks
                (list 
                 (cons 'indices  (make-datablock '((0) (1) (2))))
                 (cons 'vertices (make-datablock '((0. 0. 0.)
                                                   (1. 0. 0.)
                                                   (0. 1. 0.))))))]
       [tnode (instantiate TransformationNode
                :children (list mesh))]
       [top   (instantiate TransformationNode
                :children (list tnode)
                :position (vector -1.0 -1.0 0.0))]
       [can   (instantiate Canvas3D
                :width  1024
                :height 768
                :scene  top
                :view   #f)]
       [win (make-window 1024 768)]
       [ctx (get-context win)])
  (display "Starting main loop.")
  (newline)
  (run-glut-loop (lambda ()
                   (render ctx can)
                   (with-access tnode (TransformationNode position)
                   (if (> (vector-ref position 0) 2.)
                       (set! position (vector 0. 0. 0.))
                       (move tnode .1 .1 .0))
                   (thread-sleep! 0.1)))))
