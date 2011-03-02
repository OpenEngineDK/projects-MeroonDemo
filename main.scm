(let* ([tnode (instantiate TransformationNode)]
       [can   (instantiate Canvas3D
                :width  800
                :height 600
                :scene  tnode
                :view   #f)])
  (display "Starting main loop.")
  (letrec ([main (lambda ()
                   (begin
                     (newline)
                     ;;
                     (move tnode 1.0 2.0 3.0)
                     (show can)
                     ;;
                     (thread-sleep! 0.5)
                     (main)))])
    (main)))

