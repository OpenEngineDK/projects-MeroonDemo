
;; Context definition

(define-class GLContext Context ())

;; Canvas rendering

(define-method (render! (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  (gl-viewing-volume)
  (gl-render-scene ctx (Canvas3D-scene can)))

;; Scene rendering

(define-generic (gl-render-scene ctx (node Scene))
  (error "Unsupported scene node"))

(define-method (gl-render-scene ctx (node SceneParent))
  (do ([children (SceneParent-children node) (cdr children)])
      ((null? children))
    (gl-render-scene ctx (car children))))

(define-method (gl-render-scene ctx (node TransformationNode))
  (gl-push-transformation (TransformationNode-transformation node))
  (call-next-method) ;; i.e., on SceneParent
  (gl-pop-transformation))

(define-method (gl-render-scene ctx (node MeshNode))
  (with-access node (MeshNode datablocks)
    (let ([v? (assoc 'vertices datablocks)]
          [i? (assoc 'indices datablocks)])
      (if (and v? i?)
          (let ([vs (cdr v?)]
                [is (cdr i?)])
            (gl-apply-mesh vs is))
          (error "Invalid data block (must define verticies and indices")))))

;; Helpers and foreign functions to OpenGL

(c-define-type DataBlock (pointer "IDataBlock"))
(c-declare #<<c-declare-end
#include <cstdio>
#include <Meta/OpenGL.h>
#include <Resources/DataBlock.h>
using namespace OpenEngine::Resources;
c-declare-end
)

(define gl-apply-mesh
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

(define (gl-push-transformation trans)
  (with-access trans (Transformation translation)
    ((c-lambda (float float float) void
       "glPushMatrix(); glTranslatef(___arg1,___arg2,___arg3);")
     (vector-ref translation 0)
     (vector-ref translation 1)
     (vector-ref translation 2))))

(define gl-pop-transformation
  (c-lambda () void
    "glPopMatrix();"))

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
