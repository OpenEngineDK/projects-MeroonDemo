;; (c-declare "#include <Meta/GLUT.h>")
(c-declare #<<c-declare-end
#if defined __APPLE__
#include <GLUT/glut.h>
#else
#include <GL/glut.h>
#endif
c-declare-end
)

(define *glut-initialized* #f)
(define *glut-idle-function #f)

(c-define (glut-idle-function-callback)
    () void "glut_idle_scm_callback" ""
  (and *glut-idle-function*
       (*glut-idle-function*)))

(define glut-make-window
  (c-lambda (int int) int
#<<glut-make-window-end
int argc = 0;
glutInit(&argc, NULL);
glutInitWindowPosition(0, 0);
glutInitWindowSize(___arg1, ___arg2);
glutInitDisplayMode(GLUT_RGBA|GLUT_DOUBLE|GLUT_DEPTH);
glutIdleFunc(glut_idle_scm_callback);
___result = glutCreateWindow("Meroon Demo");
glut-make-window-end
))

(define (make-window width height)
  (if *glut-initialized*
      (error "This implementation only supports one window.")
      (begin 
        (set! *glut-initialized*
              (glut-make-window width height))
        (cons 'glut-window *glut-initialized*))))

(define (get-context win)
  (and (pair? win)
       (equal? (car win) 'glut-window)
       (make-GLUTContext (make-GLContext))))

(define (set-glut-idle-function fn)
  (set! *glut-idle-function* fn))

(define glut-swap-buffers
  (c-lambda () void
    "glutSwapBuffers();"))

(define (run-glut-loop fn)
  (set-glut-idle-function fn)
  ((c-lambda () void "glutMainLoop();")))

(define-class GLUTContext Context
  ([= gl-context :immutable]))

(define-method (render (ctx GLUTContext) (can Canvas))
  (render (GLUTContext-gl-context ctx) can)
  (glut-swap-buffers))
