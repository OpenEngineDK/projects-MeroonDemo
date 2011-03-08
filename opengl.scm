(c-define-type DataBlock (pointer "IDataBlock"))
(c-declare #<<c-declare-end
#include <cstdio>
#include <Meta/OpenGL.h>
#include <Resources/DataBlock.h>
using namespace OpenEngine::Resources;
c-declare-end
)

(define-class GLContext Context ())

;; CANVAS RENDERING

(define-method (render (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  (gl-viewing-volume)
  (gl-render-scene ctx (Canvas3D-scene can)))

;; SCENE RENDERING

(define-generic (gl-render-scene ctx (node Scene))
  (error "Unsupported scene node"))

(define (iter f lst)
  (if (pair? lst)
      (begin (f (car lst))
             (iter f (cdr lst)))
      (values)))      

(define-method (gl-render-scene ctx (node TransformationNode))
  (with-access node (TransformationNode position)
    ((c-lambda (float float float) void
       "glPushMatrix(); glTranslatef(___arg1,___arg2,___arg3);")
     (vector-ref position 0)
     (vector-ref position 1)
     (vector-ref position 2)))
  (iter (lambda (node) (gl-render-scene ctx node))
        (TransformationNode-children node))
  ((c-lambda () void
     "glPopMatrix();")))

(define-method (gl-render-scene ctx (node MeshNode))
  (with-access node (MeshNode datablocks)
    (let ([v? (assoc 'vertices datablocks)]
          [i? (assoc 'indices datablocks)])
      (if (and v? i?)
          (let ([vs (cdr v?)]
                [is (cdr i?)])
            (apply-mesh vs is))
          (error "Invalid data block (must define verticies and indices")))))

;; OpenGL functions

(define apply-mesh
  (c-lambda (DataBlock DataBlock) void
#<<apply-mesh-end
glEnableClientState(GL_VERTEX_ARRAY);
glVertexPointer(___arg1->GetDimension(), ___arg1->GetType(), 0, ___arg1->GetVoidDataPtr());
CHECK_FOR_GL_ERROR();
glDrawElements(GL_TRIANGLES, ___arg2->GetSize(), ___arg2->GetType(), ___arg2->GetVoidData());
CHECK_FOR_GL_ERROR();
glDisableClientState(GL_VERTEX_ARRAY);
apply-mesh-end
))

(define gl-viewport
  (c-lambda (int int) void
    "glViewport(0,0,___arg1,___arg2);
     CHECK_FOR_GL_ERROR();"))

(define gl-clear
  (c-lambda () void
    "glClearColor(.5,.5,.5,1);
     glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
     CHECK_FOR_GL_ERROR();"))

(define gl-viewing-volume
  (c-lambda () void
    "glMatrixMode(GL_PROJECTION);
     CHECK_FOR_GL_ERROR();
     glLoadIdentity();
     CHECK_FOR_GL_ERROR();
     glMatrixMode(GL_MODELVIEW);
     CHECK_FOR_GL_ERROR();
     glLoadIdentity();
     CHECK_FOR_GL_ERROR();"))
