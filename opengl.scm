(c-define-type FloatArray (pointer "float"))

;; Context definition

(define-class GLContext Context 
  ([= shaders :initializer list]))


;; Canvas rendering

(define-method (render! (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  (gl-viewing-volume (Projection-c-matrix (Camera-proj (Canvas3D-camera can)))
		     (Transformation-c-matrix (Camera-view (Canvas3D-camera can))))
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
	    ;; (display "gl-apply-mesh")
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
const GLchar* arg1 = ___arg1;
const GLchar* arg2 = ___arg2;
GLint compiled;
GLuint vid = glCreateShader(GL_VERTEX_SHADER);
glShaderSource(vid, 1, &arg1, NULL);
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
glShaderSource(fid, 1, &arg2, NULL);
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
  (with-access trans (Transformation c-matrix)
    ((c-lambda (FloatArray) void
       "glPushMatrix(); glMultMatrixf(___arg1);")
     c-matrix)))

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
  (c-lambda (FloatArray FloatArray) void
#<<GL-VIEWING-VOLUME-END
  float* proj = ___arg1;
  float* view = ___arg2;
  //printf("%f %f %f %f\n", proj[0], proj[4], proj[8], proj[12]);
  //printf("%f %f %f %f\n", proj[1], proj[5], proj[9], proj[13]);
  //printf("%f %f %f %f\n", proj[2], proj[6], proj[10], proj[14]);
  //printf("%f %f %f %f\n", proj[3], proj[7], proj[11], proj[15]);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glMultMatrixf(proj);
  CHECK_FOR_GL_ERROR();
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glMultMatrixf(view);
  CHECK_FOR_GL_ERROR();
GL-VIEWING-VOLUME-END
))