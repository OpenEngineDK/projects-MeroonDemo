(c-define-type FloatArray (pointer "float"))

;; Context definition

(define-class GLContext Context 
  ([= textures :initializer list]
   [= shaders :initializer list]))

(define-generic (lookup-texture-id (ctx GLContext) (texture Texture))
  (with-access ctx (GLContext textures)
    (letrec ([lookup (lambda (key xs)
		       (cond
                        [(null? xs)
                         #f]
                        [(pair? xs)
			 (let ([p (car xs)])
			   (if (pair? p)
			       (if (equal? key (car p))
				   (cdr p)
				   (lookup key (cdr xs)))
			       (error "not a key value pair")))]
			[else (error "not a list")]))])
      (lookup texture textures))))


;; Canvas rendering

(define-method (render! (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  ;; (show (Camera-view (Canvas3D-camera can)))
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
  (with-access node (MeshNode indices vertices uvs texture)
    (with-access ctx (GLContext textures)
      (if (equal? texture #f)
	  (gl-apply-mesh indices vertices uvs 0)
	  (let ([tid (lookup-texture-id ctx texture)])
	    (if (equal? tid #f)
		(begin
		  ;; (display "bind texture: ")
		  (let ([tid (gl-bind-texture texture)])
		    (set! textures (cons (cons texture tid) textures))
		    ;; (display tid)
		    ;; (display "\n")
		    (gl-apply-mesh indices vertices uvs tid)))
		(begin
		  ;; (display "found texture: ")
		    ;; (display tid)
		    ;; (display "\n")
		  (gl-apply-mesh indices vertices uvs tid))))))))

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

(define null
  (c-lambda () DataBlock "___result_voidstar = NULL;"))


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


(c-define-type CharArray (pointer "char"))

(define (gl-bind-texture texture)
  (with-access texture (Texture image)
    (with-access image (Bitmap width height c-data)
      ((c-lambda (int int CharArray) int
#<<gl-bind-texture-end

// todo: set these gl state parameters once in an inititialization phase.
// glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
//glEnable(GL_LIGHTING); 
glEnable(GL_TEXTURE_2D); 
glEnable(GL_DEPTH_TEST);						   
glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
glShadeModel(GL_SMOOTH);
CHECK_FOR_GL_ERROR();

GLuint texid;
glGenTextures(1, &texid);
CHECK_FOR_GL_ERROR();

//printf("tid: %x\n", texid);
//printf("width: %d height: %d data: %x\n", ___arg1, ___arg2, ___arg3);

glBindTexture(GL_TEXTURE_2D, texid);

glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
CHECK_FOR_GL_ERROR();

glTexImage2D(GL_TEXTURE_2D,
	     0, // mipmap level
	     GL_RGBA,
	     ___arg1,
	     ___arg2,
	     0, // border
	     GL_RGBA,
	     GL_UNSIGNED_BYTE,
	     ___arg3);
CHECK_FOR_GL_ERROR();
glBindTexture(GL_TEXTURE_2D, 0);
___result = texid;

gl-bind-texture-end
) width height c-data))))

(define gl-apply-mesh
  (c-lambda (DataBlock DataBlock DataBlock int) void
#<<apply-mesh-end


if (___arg4) {
  //printf("binding tid: %x\n", ___arg4);
  glBindTexture(GL_TEXTURE_2D, ___arg4);
}
else {
  glBindTexture(GL_TEXTURE_2D, 0);
}

glEnableClientState(GL_VERTEX_ARRAY);
glVertexPointer(___arg2->GetDimension(), ___arg2->GetType(), 0, ___arg2->GetVoidDataPtr());
CHECK_FOR_GL_ERROR();

if (___arg3) {
  //printf("using uvs: %x\n", ___arg3);
  glClientActiveTexture(GL_TEXTURE0);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(___arg3->GetDimension(), GL_FLOAT, 0, ___arg3->GetVoidDataPtr());
}
glDrawElements(GL_TRIANGLES, ___arg1->GetSize(), ___arg1->GetType(), ___arg1->GetVoidData());
CHECK_FOR_GL_ERROR();

glDisableClientState(GL_VERTEX_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glBindTexture(GL_TEXTURE_2D, 0);

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

  //printf("%f %f %f %f\n", view[0], view[4], view[8], view[12]);
  //printf("%f %f %f %f\n", view[1], view[5], view[9], view[13]);
  //printf("%f %f %f %f\n", view[2], view[6], view[10], view[14]);
  //printf("%f %f %f %f\n", view[3], view[7], view[11], view[15]);


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