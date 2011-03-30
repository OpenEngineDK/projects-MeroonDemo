;; Context definition

(define-class GLContext Context 
  ([= textures :initializer list]
   [= shaders :initializer list]
   [= vbos :initializer list]
   [= num-lights :initializer (lambda () 0)]
   [= vbo? :initializer (lambda () #f)]
   [= fbo? :initializer (lambda () #f)]))

(define-generic (gl-lookup-texture-id (ctx GLContext) texture)
  (cond
    [(assoc texture (GLContext-textures ctx))
     => (lambda (p) (cdr p))]
    [else #f]))

(define-generic (gl-lookup-vbo-id (ctx GLContext) db)
  (cond
    [(assoc db (GLContext-vbos ctx))
     => (lambda (p) (cdr p))]
    [else #f]))

(define-method (initialize-context! (ctx GLContext))
  (with-access ctx (GLContext vbo?)
    (set! vbo? ((c-lambda () bool "___result = glewIsSupported(\"GL_VERSION_2_0\");")))
    (set! fbo? ((c-lambda () bool "___result = (glewGetExtension(\"GL_EXT_framebuffer_object\") == GL_TRUE);"))))  
  ((c-lambda () void #<<INIT_GL_CONTEXT_END

// todo: set these gl state parameters once in an inititialization phase.
// glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
glEnable(GL_LIGHTING); 
glEnable(GL_TEXTURE_2D); 
glEnable(GL_DEPTH_TEST);						   
glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
glShadeModel(GL_SMOOTH);
CHECK_FOR_GL_ERROR();

INIT_GL_CONTEXT_END
)))

;; Canvas rendering

(define-method (render! (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  (gl-viewing-volume (Projection-c-matrix (Camera-proj (Canvas3D-camera can)))
		     (Transformation-c-matrix (Camera-view (Canvas3D-camera can))))
  (with-access ctx (GLContext num-lights)
    (set! num-lights 0))
  (gl-setup-lights ctx (Canvas3D-scene can))
  (gl-render-scene ctx (Canvas3D-scene can)))


;; Scene rendering
(define-generic (gl-render-scene ctx (node Object))
  (error "Unsupported scene node"))

(define-method (gl-render-scene ctx (node Scene))
  #f)

(define-method (gl-render-scene ctx (node SceneParent))
  (do ([children (SceneParent-children node) (cdr children)])
      ((null? children))
    (gl-render-scene ctx (car children))))

(define-method (gl-render-scene ctx (node TransformationNode))
  (gl-push-transformation (TransformationNode-transformation node))
  (call-next-method) ;; i.e., on SceneParent
  (gl-pop-transformation))

;; render bones
(define-method (gl-render-scene ctx (node BoneNode))
 #f)
  ;; (gl-push-transformation (BoneNode-transformation node))
  ;; (call-next-method) ;; i.e., on SceneParent
  ;; (gl-pop-transformation))


(define-generic (gl-render-mesh ctx (mesh Object))
  (error "Unsupported mesh type"))

(define-generic (gl-render-mesh-vbo ctx (mesh Object))
  (error "Unsupported mesh type"))

(define (foldl f n l)
  (letrec ([visit (lambda (l r)
                    (cond
                      [(null? l)
                       r]
                      [(pair? l)
                       (visit (cdr l) (f r (car l)))]
                      [(error "invalid list")]))])
    (visit l n)))


(define (update-animation mesh)
  (with-access mesh (AnimatedMesh 
                     indices
                     vertices
                     normals
                     bind-pose-vertices 
                     bind-pose-normals
                     bones)
    (if (foldl (lambda (b r) (or b r))
               #f
               (map (lambda (b) (BoneNode-dirty b))
                    bones)) ;; if at least one bone is dirty ... prettier code needed!
        (begin
          (init-skin-mesh vertices normals)
          (map (lambda (b) 
                 (with-access b (BoneNode acc-transformation dirty)
                   (set! dirty #f)
                   (skin-mesh bind-pose-vertices
                              bind-pose-normals
                              vertices
                              normals
                              (Transformation-c-matrix acc-transformation)
                              (Quaternion-c-matrix ;; use matrix from quaternion to rotate normals
                               (Transformation-rotation 
                                acc-transformation))
                              (BoneNode-c-weights b))))
               bones)
          #t)
        #f)))

(define-method (gl-render-mesh ctx (mesh AnimatedMesh))
  (update-animation mesh)
  (call-next-method))

(define (fetch-texture ctx texture)
  (with-access ctx (GLContext textures)
    (if texture
        (let ([tid (gl-lookup-texture-id ctx texture)])
          (if tid
              tid
            (let ([tid (gl-make-texture texture)])
              (set! textures (cons (cons texture tid) textures))
              tid)))
        0)))


(define-method (gl-render-mesh ctx (mesh Mesh))
  (with-access mesh (Mesh indices vertices normals uvs texture)
      (let ([tid (fetch-texture ctx texture)])
        (gl-apply-mesh indices vertices normals uvs tid))))

(define (fetch-vbo ctx db index? usage)
  (let ([vbo-id (gl-lookup-vbo-id ctx db)])
    (if vbo-id
        vbo-id
        (let ([vbo-id (gl-make-vbo db index? usage)])
          (with-access ctx (GLContext vbos)
            (set! vbos (cons (cons db vbo-id) vbos)))
          vbo-id))))

(define-method (gl-render-mesh-vbo ctx (mesh AnimatedMesh))
  (let ([updated (update-animation mesh)])
    
    (with-access mesh (Mesh indices vertices normals uvs texture)
      (let ([index-vbo (fetch-vbo ctx indices #t 0)]
            [vertex-vbo (fetch-vbo ctx vertices #f 1)]
            [normal-vbo (fetch-vbo ctx normals #f 1)]
            [uv-vbo (fetch-vbo ctx uvs #f 0)]
            [tid (fetch-texture ctx texture)])
        (if updated
            (begin (gl-update-vbo vertex-vbo vertices)
                   (gl-update-vbo normal-vbo normals)))
        (gl-apply-mesh-vbo index-vbo vertex-vbo normal-vbo uv-vbo tid indices)))))
    
    


(define-method (gl-render-mesh-vbo ctx (mesh Mesh))
  (with-access mesh (Mesh indices vertices normals uvs texture)
    (let ([index-vbo (fetch-vbo ctx indices #t 0)]
          [vertex-vbo (fetch-vbo ctx vertices #f 0)]
          [normal-vbo (fetch-vbo ctx normals #f 0)]
          [uv-vbo (fetch-vbo ctx uvs #f 0)]
          [tid (fetch-texture ctx texture)])
      (gl-apply-mesh-vbo index-vbo vertex-vbo normal-vbo uv-vbo tid indices))))
  
(define-method (gl-render-scene ctx (node MeshNode))
  (if (GLContext-vbo? ctx)
      (gl-render-mesh-vbo ctx (MeshNode-mesh node))
      (gl-render-mesh ctx (MeshNode-mesh node))))

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
            
            
(define-generic (gl-setup-lights ctx (node Object))
  (error "Unsupported scene node"))

(define-generic (gl-setup-light ctx (light Light))
  (error "Unsupported scene node"))

(define-method (gl-setup-lights ctx (node SceneParent))
  (do ([children (SceneParent-children node) (cdr children)])
      ((null? children))
    (gl-setup-lights ctx (car children))))

(define-method (gl-setup-lights ctx (node TransformationNode))
  (gl-push-transformation (TransformationNode-transformation node))
  (call-next-method) ;; i.e., on SceneParent
  (gl-pop-transformation))

(define-method (gl-setup-lights ctx (node Scene))
  #f)

(define-method (gl-setup-lights ctx (node LightNode))
  (gl-setup-light ctx (LightNode-light node)))

(define-method (gl-setup-light ctx (light PointLight))
  (with-access ctx (GLContext num-lights)
    (with-access light (PointLight ambient diffuse specular)
      ((c-lambda (int scheme-object scheme-object scheme-object) void 
#<<c-gl-setup-light-end

const ___SCMOBJ scm_ar  = ___VECTORREF(___arg2, 0);
const ___SCMOBJ scm_ag  = ___VECTORREF(___arg2, 4);
const ___SCMOBJ scm_ab  = ___VECTORREF(___arg2, 8);
const ___SCMOBJ scm_aa  = ___VECTORREF(___arg2, 12);

const ___SCMOBJ scm_dr = ___VECTORREF(___arg3, 0);
const ___SCMOBJ scm_dg = ___VECTORREF(___arg3, 4);
const ___SCMOBJ scm_db = ___VECTORREF(___arg3, 8);
const ___SCMOBJ scm_da = ___VECTORREF(___arg3, 12);

const ___SCMOBJ scm_sr = ___VECTORREF(___arg4, 0);
const ___SCMOBJ scm_sg = ___VECTORREF(___arg4, 4);
const ___SCMOBJ scm_sb = ___VECTORREF(___arg4, 8);
const ___SCMOBJ scm_sa = ___VECTORREF(___arg4, 12);

float ambient[4];
float diffuse[4];
float specular[4];

___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_ar, ambient[0], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_ag, ambient[1], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_ab, ambient[2], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_aa, ambient[3], 12);

___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_dr, diffuse[0], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_dg, diffuse[1], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_db, diffuse[2], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_da, diffuse[3], 12);

___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sr, specular[0], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sg, specular[1], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sb, specular[2], 12);
___BEGIN_CFUN_SCMOBJ_TO_FLOAT(scm_sa, specular[3], 12);

___END_CFUN_SCMOBJ_TO_FLOAT(scm_sa, specular[3], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sb, specular[2], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sg, specular[1], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_sr, specular[0], 12);

___END_CFUN_SCMOBJ_TO_FLOAT(scm_da, diffuse[3], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_db, diffuse[2], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_dg, diffuse[1], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_dr, diffuse[0], 12);

___END_CFUN_SCMOBJ_TO_FLOAT(scm_aa, ambient[3], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_ab, ambient[2], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_ag, ambient[1], 12);
___END_CFUN_SCMOBJ_TO_FLOAT(scm_ar, ambient[0], 12);

GLint light = GL_LIGHT0 + ___arg1;
const float pos[] = {0.0, 0.0, 0.0, 1.0};
glLightfv(light, GL_POSITION, pos);
glLightfv(light, GL_AMBIENT, ambient);
glLightfv(light, GL_DIFFUSE, diffuse);
glLightfv(light, GL_SPECULAR, specular);

    // glLightf(light, GL_CONSTANT_ATTENUATION, node->constAtt);
    // glLightf(light, GL_LINEAR_ATTENUATION, node->linearAtt);
    // glLightf(light, GL_QUADRATIC_ATTENUATION, node->quadAtt);
    glEnable(light);
c-gl-setup-light-end
) num-lights ambient diffuse specular)
    (set! num-lights (+ 1 num-lights)))))

(define stack-height 
  (c-lambda () int "glGetIntegerv(GL_MAX_MODELVIEW_STACK_DEPTH, &___result);"))

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

#include <vector>

using namespace OpenEngine::Resources;
using namespace std;

typedef vector<pair<unsigned int,float> > Weights;

const GLint gl_color_formats[]          = {GL_RGB, GL_RGBA, GL_BGR, GL_BGRA};
const GLint gl_internal_color_formats[] = {GL_RGB, GL_RGBA, GL_RGB, GL_RGBA};
const GLint gl_wrappings[]              = {GL_CLAMP, GL_REPEAT};
const GLint gl_buffer_usage[]           = {GL_STATIC_DRAW, GL_DYNAMIC_DRAW};

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

(define gl-update-vbo
  (c-lambda (int DataBlock) void
#<<gl-update-vbo
GLint buffer_type = GL_ARRAY_BUFFER;
unsigned int type_size = sizeof(float);

glBindBuffer(buffer_type, ___arg1);
// fill data

unsigned int size = type_size * ___arg2->GetSize() * ___arg2->GetDimension();

glBufferData(buffer_type,
             size,
             ___arg2->GetVoidDataPtr(),
             GL_DYNAMIC_DRAW);
CHECK_FOR_GL_ERROR(); 
gl-update-vbo
))

(define gl-make-vbo
  (c-lambda (DataBlock bool int) int 
#<<gl-bind-vbo-end
if (___arg1) { 

//create buffer
GLuint id;
glGenBuffers(1, &id);
CHECK_FOR_GL_ERROR();

//bind buffer
GLint buffer_type;
unsigned int type_size;
if (___arg2) {
    buffer_type = GL_ELEMENT_ARRAY_BUFFER;
    type_size = sizeof(unsigned int);
}
else {
  buffer_type = GL_ARRAY_BUFFER;
  type_size = sizeof(float);
}
glBindBuffer(buffer_type, id);
CHECK_FOR_GL_ERROR();

// fill data
unsigned int size = type_size * ___arg1->GetSize() * ___arg1->GetDimension();

glBufferData(buffer_type,
             size,
             ___arg1->GetVoidDataPtr(),
             gl_buffer_usage[___arg3]);
CHECK_FOR_GL_ERROR(); 

// unbind again
glBindBuffer(buffer_type, 0);
CHECK_FOR_GL_ERROR();

___result = id; 
}
else ___result = 0; // right now we simply associate a non-existent buffer with 0
gl-bind-vbo-end
))

(define (gl-make-texture texture)
  (with-access texture (Texture image wrapping-s wrapping-t)
    (if image
        (with-access image (Bitmap width height format c-data)
          (newline)
          (let ([gl-wrapping 
                 (lambda (wrapping) 
                   (cond [(eqv? wrapping 'clamp)
                          0]
                         [(eqv? wrapping 'repeat)
                          1]
                         [(error "Unsupported texture wrapping format")]))])
            (let ([gl-format-index 
                   (cond [(eqv? format 'rgb)
                          0]
                         [(eqv? format 'rgba)
                          1]
                         [(eqv? format 'bgr)
                          2]
                         [(eqv? format 'bgra)
                          3]
                         [(error "Unsupported texture color format")])]
                  [gl-wrapping-index-s (gl-wrapping wrapping-s)]
                  [gl-wrapping-index-t (gl-wrapping wrapping-t)])
              ((c-lambda (int int int int int (pointer "char")) int
#<<gl-make-texture-end
const int width             = ___arg1;
const int height            = ___arg2;
const GLint format          = gl_color_formats[___arg3];
const GLint internal_format = gl_internal_color_formats[___arg3];
const GLint s_wrapping      = gl_wrappings[___arg4];
const GLint t_wrapping      = gl_wrappings[___arg5];
const char* data            = ___arg6;

GLuint texid;
glGenTextures(1, &texid);
CHECK_FOR_GL_ERROR();

//printf("tid: %x\n", texid);
//printf("width: %d height: %d data: %x\n", width, height, data);

glBindTexture(GL_TEXTURE_2D, texid);

glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, s_wrapping);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, t_wrapping);
CHECK_FOR_GL_ERROR();

glTexImage2D(GL_TEXTURE_2D,
	     0, // mipmap level
	     internal_format, // internal format (ex. source format with compression)
	     width,
	     height,
	     0, // border
	     format, // source format (ex. rgb, rgba, luminance and what not)
	     GL_UNSIGNED_BYTE, // for now assume one byte per color channel.
	     data);
CHECK_FOR_GL_ERROR();
glBindTexture(GL_TEXTURE_2D, 0);
___result = texid;

gl-make-texture-end
) width height gl-format-index gl-wrapping-index-s 
  gl-wrapping-index-t c-data))))
        0)))


(define gl-apply-mesh-vbo
  (c-lambda (int int int int int DataBlock) void
#<<apply-mesh-vbo-end

glBindTexture(GL_TEXTURE_2D, ___arg5);

glBindBuffer(GL_ARRAY_BUFFER, ___arg2);  
glEnableClientState(GL_VERTEX_ARRAY);
glVertexPointer(3, GL_FLOAT, 0, 0);
CHECK_FOR_GL_ERROR();

if (___arg3) {
  glEnableClientState(GL_NORMAL_ARRAY);
  glBindBuffer(GL_ARRAY_BUFFER, ___arg3);  
  glNormalPointer(GL_FLOAT, 0, 0);
  CHECK_FOR_GL_ERROR();
}

if (___arg4) {
  glClientActiveTexture(GL_TEXTURE0); 
  glEnableClientState(GL_TEXTURE_COORD_ARRAY); 
  glBindBuffer(GL_ARRAY_BUFFER, ___arg4);
  glTexCoordPointer(2, GL_FLOAT, 0, 0);
  CHECK_FOR_GL_ERROR();
}

glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ___arg1);  
glDrawElements(GL_TRIANGLES, ___arg6->GetSize(), GL_UNSIGNED_INT, 0);
CHECK_FOR_GL_ERROR();

glDisableClientState(GL_VERTEX_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glDisableClientState(GL_NORMAL_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glBindTexture(GL_TEXTURE_2D, 0);
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
glBindBuffer(GL_ARRAY_BUFFER, 0);

apply-mesh-vbo-end
))
    

(define gl-apply-mesh
  (c-lambda (DataBlock DataBlock DataBlock DataBlock int) void
#<<apply-mesh-end


if (___arg5) {
  //printf("binding tid: %x\n", ___arg5);
  glBindTexture(GL_TEXTURE_2D, ___arg5);
}
else {
  glBindTexture(GL_TEXTURE_2D, 0);
}

glEnableClientState(GL_VERTEX_ARRAY);
glVertexPointer(___arg2->GetDimension(), ___arg2->GetType(), 0, ___arg2->GetVoidDataPtr());
CHECK_FOR_GL_ERROR();

if (___arg3) {
  //printf("using normals: %x\n", ___arg3);
  glEnableClientState(GL_NORMAL_ARRAY);
  glNormalPointer(GL_FLOAT, 0, ___arg3->GetVoidDataPtr());
}

if (___arg4) {
  //printf("using uvs: %x\n", ___arg4);
  glClientActiveTexture(GL_TEXTURE0);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(___arg4->GetDimension(), GL_FLOAT, 0, ___arg4->GetVoidDataPtr());
}

glDrawElements(GL_TRIANGLES, ___arg1->GetSize(), ___arg1->GetType(), ___arg1->GetVoidData());
CHECK_FOR_GL_ERROR();

glDisableClientState(GL_VERTEX_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glDisableClientState(GL_NORMAL_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glBindTexture(GL_TEXTURE_2D, 0);

apply-mesh-end
))

(define (gl-push-transformation trans)
  (with-access trans (Transformation c-matrix)
    ((c-lambda ((pointer float)) void
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
  (c-lambda ((pointer float) (pointer float)) void
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


;; --- skinning ---
;; (maybe this kind of skinning should be moved to animation.scm since
;; it is not gl specific.
(define init-skin-mesh
  (c-lambda (DataBlock ;; dest-verts
             DataBlock);; dest-norms
      void
#<<c-init-skin-mesh-end
memset(___arg1->GetVoidData(), 0x0, sizeof(float) * ___arg1->GetSize() * ___arg1->GetDimension());
memset(___arg2->GetVoidData(), 0x0, sizeof(float) * ___arg2->GetSize() * ___arg2->GetDimension());
c-init-skin-mesh-end
))

(c-define-type Weights (pointer "Weights"))

(c-declare #<<c-declare-end

inline void mul_vertex(float* src, float* dest, float* m) {
   dest[0] = src[0] * m[0] + src[1] * m[4] + src[2] * m[8]  + m[12];
   dest[1] = src[0] * m[1] + src[1] * m[5] + src[2] * m[9]  + m[13];
   dest[2] = src[0] * m[2] + src[1] * m[6] + src[2] * m[10] + m[14];
}

inline void mul_normal(float* src, float* dest, float* m) {
   dest[0] = src[0] * m[0] + src[1] * m[3] + src[2] * m[6];
   dest[1] = src[0] * m[1] + src[1] * m[4] + src[2] * m[7];
   dest[2] = src[0] * m[2] + src[1] * m[5] + src[2] * m[8];
}

c-declare-end
)

(define skin-mesh
  (c-lambda (DataBlock         ;; src-verts
             DataBlock         ;; src-norms
             DataBlock         ;; dest-verts
             DataBlock         ;; dest-norms
             (pointer "float") ;; bone matrix
             (pointer "float") ;; bone rotation matrix (no scaling)
             Weights)          ;; vertex weights
      void 
#<<c-skin-mesh-end
// printf("skin\n");

float* src_verts = (float*)___arg1->GetVoidData();
float* src_norms = (float*)___arg2->GetVoidData();
float* dest_verts = (float*)___arg3->GetVoidData();
float* dest_norms = (float*)___arg4->GetVoidData();
float* m = ___arg5;
float* m_rot = ___arg6;

vector<pair<unsigned int, float> >::iterator itr = ___arg7->begin();
for (; itr != ___arg7->end(); ++itr) {
    unsigned int index = itr->first;
    float weight = itr->second; 
 
    float* src_v = &src_verts[index*3];
    float* src_n = &src_norms[index*3];
 
    float* dest_v = &dest_verts[index*3];
    float* dest_n = &dest_norms[index*3];

    float tmp[3];
    // apply weighted bone transformation
    mul_vertex(src_v, tmp, m);
    dest_v[0] += tmp[0] * weight;
    dest_v[1] += tmp[1] * weight;
    dest_v[2] += tmp[2] * weight;

    mul_normal(src_n, tmp, m_rot);
    dest_n[0] += tmp[0] * weight;
    dest_n[1] += tmp[1] * weight;
    dest_n[2] += tmp[2] * weight;
}
c-skin-mesh-end
))
