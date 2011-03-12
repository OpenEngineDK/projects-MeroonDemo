
;; Context definition

(define-class GLContext Context 
  ([= shaders :initializer list]))


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

(define-method (gl-render-scene ctx (node ShaderNode))
  (let ([shader-tag (ShaderNode-tags node 0)])
    (with-access ctx (GLContext shaders)
      
      (cond 
        [(assoc shader-tag shaders)
         => (lambda (p)
              (gl-apply-shader (cdr p)))]
        [else 
         (let* ([shader (assoc shader-tag shader-programs)]
                [vert (cadr shader)]
                [frag (caddr shader)])
           (set! shaders (cons (cons shader-tag
                                    (gl-make-program vert frag)) 
                               shaders)))])
      (call-next-method))))
            
            


;;; shaders

(define shader-programs
  (list
    (list 'blue
#<<BLUE-VERT-END
void main () {
  gl_Position = ftransform();         
}
BLUE-VERT-END
#<<BLUE-FRAG-END
void main () {
  gl_FragColor = vec4(0., 0. , 1. ,1. );
}
BLUE-FRAG-END
)
))

;; Helpers and foreign functions to OpenGL

(c-define-type DataBlock (pointer "IDataBlock"))
(c-declare #<<c-declare-end
#include <cstdio>
#include <Meta/OpenGL.h>
#include <Resources/DataBlock.h>
using namespace OpenEngine::Resources;
c-declare-end
)

(define gl-make-program
  (c-lambda (char-string char-string) int 
#<<GL-MAKE-PROGRAM-END

GLint compiled;
GLuint vid = glCreateShader(GL_VERTEX_SHADER);
glShaderSource(vid, 1, &(const GLchar*)___arg1, NULL);
glCompileShader(vid);


glGetShaderiv(vid, GL_COMPILE_STATUS, &compiled);
if (!compiled) {
printf("failed to compile vertex: %s\n",___arg1);

            GLsizei bufsize;
            const int maxBufSize = 100;
            char buffer[maxBufSize];
            glGetShaderInfoLog(vid, maxBufSize, &bufsize, buffer);
            printf("%s\n",buffer);

}
GLuint fid = glCreateShader(GL_FRAGMENT_SHADER);
glShaderSource(fid, 1, &(const GLchar*)___arg2, NULL);
glCompileShader(fid);

glGetShaderiv(fid, GL_COMPILE_STATUS, &compiled);
if (!compiled) {
printf("failed to compile fragment: %s\n",___arg2);
            GLsizei bufsize;
            const int maxBufSize = 100;
            char buffer[maxBufSize];
            glGetShaderInfoLog(fid, maxBufSize, &bufsize, buffer);
            printf("%s\n",buffer);
}

GLuint pid = glCreateProgram();
glAttachShader(pid, vid);
glAttachShader(pid, fid);
glLinkProgram(pid);
GLint linked;
glGetProgramiv(pid, GL_LINK_STATUS, &linked);
if (!linked)
    printf("Fuuuuuuuu\n");

___result = pid;

GL-MAKE-PROGRAM-END
))

(define gl-apply-shader
  (c-lambda (int) void
#<<APPLY-SHADER-END
glUseProgram(___arg1);
APPLY-SHADER-END
))


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
