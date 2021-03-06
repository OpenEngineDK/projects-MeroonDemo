;; Context definition
(define-class GLContext Context 
  ([= _textures :initializer make-table]
   [= _meshes   :initializer make-table]
;;   [= shaders  :initializer list]
   [= vbos :initializer list]
   [= vbo? :initializer (lambda () #f)]
   [= fbo? :initializer (lambda () #f)]))

(define (gl-lookup-vbo-id ctx db)
  (cond
    [(assoc db (GLContext-vbos ctx))
     => (lambda (p) (cdr p))]
    [else #f]))

(define-method (initialize-context! (ctx GLContext))
  (with-access ctx (GLContext vbo? fbo?)
    (set! vbo? #f) ;; no vbo support before vbo's use new VertexAttribute type.
;;          ((c-lambda () bool 
;;             "___result = glewIsSupported(\"GL_VERSION_2_0\");")))
    (set! fbo? 
          ((c-lambda () bool 
             "___result = (glewGetExtension(\"GL_EXT_framebuffer_object\") == GL_TRUE);"))))
  ((c-lambda () void #<<INIT_GL_CONTEXT_END

// todo: set these gl state parameters once in an inititialization phase.
// glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
glEnable(GL_LIGHTING); 
glEnable(GL_TEXTURE_2D); 
glEnable(GL_DEPTH_TEST); 
glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
glShadeModel(GL_SMOOTH);
glDisable(GL_CULL_FACE);
CHECK_FOR_GL_ERROR();

INIT_GL_CONTEXT_END
)))

;; Canvas rendering

(define-method (render! (ctx GLContext) (can Canvas3D))
  (gl-clear) ;; might not want to clear here...
  (gl-viewport (Canvas-width can) (Canvas-height can))
  (set-gl-view-matrix! (Camera-view (Canvas3D-camera can)))
  (gl-viewing-volume (Projection-c-matrix (Camera-proj (Canvas3D-camera can))))
  (gl-setup-lights! ctx (Canvas3D-scene can))
  (gl-render-scene! ctx (Canvas3D-scene can)))

;; Scene rendering
(define-generic (gl-render-scene! ctx (node Scene))
  (error "Unsupported scene node"))

(define-method (gl-render-scene! ctx (node SceneLeaf))
  (values))

(define-method (gl-render-scene! ctx (node SceneNode))
  (do ([children (SceneNode-children node) (cdr children)])
      ((null? children))
    (gl-render-scene! ctx (car children))))

(define-method (gl-render-scene! ctx (node TransformationNode))
  (gl-push-transformation (TransformationNode-transformation node))
  (call-next-method) ;; i.e., on SceneNode
  (gl-pop-transformation))

;; render bones
(define-method (gl-render-scene! ctx (node BoneNode))
(values))
  ;; (gl-push-transformation (BoneNode-transformation node))
  ;; (call-next-method) ;; i.e., on SceneNode
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
                      [else (error "Invalid list")]))])
    (visit l n)))

(define (update-animation ctx mesh)
  (with-access mesh (AnimatedMesh 
                     bind-pose-vertices 
                     bind-pose-normals
                     bones)
    (if (foldl (lambda (b r) (or b r)) #f
               (map 
                (lambda (b) (BoneNode-dirty b))
                bones)) ;; if at least one bone is dirty ... prettier code needed!
        (let ([gl-mesh (fetch-gl-mesh ctx mesh)])
          (init-skin-mesh gl-mesh)
          (map (lambda (b) 
                 (with-access b (BoneNode acc-transformation dirty)
                   (set! dirty #f)
                   (set-gl-matrix! acc-transformation)
                   (set-gl-rotation-matrix! acc-transformation)
                   (skin-mesh gl-mesh
                              (VertexAttribute-data bind-pose-vertices)
                              (VertexAttribute-data bind-pose-normals)
                              (BoneNode-c-weights b))))
               bones)
          #t)
        #f)))

(define-method (gl-render-mesh ctx (mesh AnimatedMesh))
  (update-animation ctx mesh)
  (call-next-method))

(define (fetch-texture ctx texture)
  (with-access ctx (GLContext _textures)
    (if texture
        (let ([tid (table-ref _textures texture #f)])
          (if tid
              tid
              (let ([tid (gl-make-texture texture)])
                (table-set! _textures texture tid) ;;(cons (cons texture tid) _textures))
                tid)))
        0)))

(c-define-type GLMesh (struct "GLMesh"))

(define (gl-attrib-type-id attr)
  (cond
    [(eqv? attr 'uint8)
     0]
    [(eqv? attr 'uint16)
     1]
    [(eqv? attr 'uint32)
     2]
    [(eqv? attr 'int16)
     3]
    [(eqv? attr 'int32)
     4]
    [(eqv? attr 'float32)
     5]
    [else (error "Unsupported vertex attribute type")]))

(define (make-gl-mesh mesh)
  (with-access mesh (Mesh indices vertices normals uvs colors)
    (let ([gl-mesh 
           ((c-lambda () GLMesh
              "___result_voidstar = new GLMesh(make_gl_mesh());"))])
      (with-access indices (VertexAttribute elm-type elm-count data)
        ((c-lambda (GLMesh int int (pointer void)) void
           "___arg1.indices = make_gl_attribute(gl_attrib_types[___arg2], 1, ___arg3, ___arg4);") 
         gl-mesh (gl-attrib-type-id elm-type) elm-count data))

      (with-access vertices (VertexAttribute elm-type elm-size elm-count data)
        ((c-lambda (GLMesh int int int (pointer void)) void
           "___arg1.vertices = make_gl_attribute(gl_attrib_types[___arg2], ___arg3, ___arg4, ___arg5);") 
         gl-mesh (gl-attrib-type-id elm-type) elm-size elm-count data))

      (if normals
          (with-access normals (VertexAttribute elm-type elm-size elm-count data)
            ((c-lambda (GLMesh int int int (pointer void)) void
               "___arg1.normals = make_gl_attribute(gl_attrib_types[___arg2], ___arg3, ___arg4, ___arg5);")
             gl-mesh (gl-attrib-type-id elm-type) elm-size elm-count data)))

      (if uvs
          (with-access uvs (VertexAttribute elm-type elm-size elm-count data)
            ((c-lambda (GLMesh int int int (pointer void)) void
               "___arg1.uvs = make_gl_attribute(gl_attrib_types[___arg2], ___arg3, ___arg4, ___arg5);")
             gl-mesh (gl-attrib-type-id elm-type) elm-size elm-count data)))
      
      (if colors
          (with-access colors (VertexAttribute elm-type elm-size elm-count data)
            ((c-lambda (GLMesh int int int (pointer void)) void
               "___arg1.colors = make_gl_attribute(gl_attrib_types[___arg2], ___arg3, ___arg4, ___arg5);")
             gl-mesh (gl-attrib-type-id elm-type) elm-size elm-count data)))
      gl-mesh)))

(define (fetch-gl-mesh ctx mesh)
  (with-access ctx (GLContext _meshes)
    (let ([gl-mesh (table-ref _meshes mesh #f)])
      (if gl-mesh
          gl-mesh
          (begin
            (set! gl-mesh (make-gl-mesh mesh))
            (table-set! _meshes mesh gl-mesh)
            gl-mesh)))))

(define-method (gl-render-mesh ctx (mesh Mesh))
  (with-access mesh (Mesh indices vertices normals uvs colors texture)
      (let ([tid (fetch-texture ctx texture)])
        (gl-apply-mesh (fetch-gl-mesh ctx mesh) tid))))

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
    
    (with-access mesh (Mesh indices vertices normals uvs colors texture)
      (let ([index-vbo (fetch-vbo ctx indices #t 0)]
            [vertex-vbo (fetch-vbo ctx vertices #f 1)]
            [normal-vbo (fetch-vbo ctx normals #f 1)]
            [uv-vbo (fetch-vbo ctx uvs #f 0)]
            [colors-vbo (fetch-vbo ctx colors #f 0)]
            [tid (fetch-texture ctx texture)])
        (if updated
            (begin (gl-update-vbo vertex-vbo vertices)
                   (gl-update-vbo normal-vbo normals)))
        (gl-apply-mesh-vbo index-vbo vertex-vbo normal-vbo uv-vbo colors-vbo tid indices)))))

(define-method (gl-render-mesh-vbo ctx (mesh Mesh))
  (with-access mesh (Mesh indices vertices normals uvs colors texture)
    (let ([index-vbo (fetch-vbo ctx indices #t 0)]
          [vertex-vbo (fetch-vbo ctx vertices #f 0)]
          [normal-vbo (fetch-vbo ctx normals #f 0)]
          [uv-vbo (fetch-vbo ctx uvs #f 0)]
          [colors-vbo (fetch-vbo ctx colors #f 0)]
          [tid (fetch-texture ctx texture)])
      (gl-apply-mesh-vbo index-vbo vertex-vbo normal-vbo uv-vbo colors-vbo tid indices))))
  
(define-method (gl-render-scene! ctx (node MeshLeaf))
  (if (GLContext-vbo? ctx)
      (gl-render-mesh-vbo ctx (MeshLeaf-mesh node))
      (gl-render-mesh ctx (MeshLeaf-mesh node))))

;; (define-method (gl-render-scene! ctx (node ShaderNode))
;;   (let ([shader-tag (ShaderNode-tags node 0)])
;;     (with-access ctx (GLContext shaders)
      
;;       (cond 
;;         [(assoc shader-tag shaders)
;;          => (lambda (p)
;;               (gl-apply-shader (cdr p)))]
;;         [else 
;;          (let* ([shader (assoc shader-tag shader-programs)]
;;                 [vert (cadr shader)]
;;                 [frag (caddr shader)])
;;            (set! shaders (cons (cons shader-tag
;;                                      (gl-make-program vert frag)) 
;;                                shaders)))])
;;       (call-next-method))))
                   

;; --- traverse scene graph and setup lighting parameters ---

(define gl-max-lights
  (c-lambda () int 
    "GLint max;
     glGetIntegerv(GL_MAX_LIGHTS, &max);
     ___result = max;"))

(define gl-turn-off-lights
  (c-lambda (int int) void
    "for (GLint i = ___arg1 + GL_LIGHT0; i < ___arg2 + GL_LIGHT0; ++i) glDisable(i);"))

(define (gl-setup-lights! ctx scene)
  (let ([light-count (_gl-setup-lights! ctx scene 0)])
    (gl-turn-off-lights light-count (gl-max-lights))
    light-count))

(define-generic (_gl-setup-lights! ctx (scene Scene) light-count)
  (error "Unsupported scene node"))

(define-method (_gl-setup-lights! ctx (leaf SceneLeaf) light-count)
  light-count)

(define-method (_gl-setup-lights! ctx (node SceneNode) light-count)
  (do ([children (SceneNode-children node) (cdr children)])
      ((null? children))
    (set! light-count (_gl-setup-lights! ctx (car children) light-count)))
  light-count)

(define-method (_gl-setup-lights! ctx (node TransformationNode) light-count)
  (gl-push-transformation (TransformationNode-transformation node))
  (let ([lc (call-next-method)]) ;; i.e., on SceneNode
    (gl-pop-transformation)
    lc))

(define-method (_gl-setup-lights! ctx (leaf LightLeaf) light-count)
  (gl-setup-light! ctx (LightLeaf-light leaf) light-count))

(define-generic (gl-setup-light! ctx (light Light) light-count)
  (error "Unsupported light source"))

(define-method (gl-setup-light! ctx (light DirectionalLight) light-count)
  (with-access light (DirectionalLight ambient diffuse specular direction)
    ((c-lambda (int scheme-object scheme-object scheme-object scheme-object) void 
#<<c-gl-setup-light-end
float* ambient  = ___CAST(___F32*,___BODY(___arg2));
float* diffuse  = ___CAST(___F32*,___BODY(___arg3));
float* specular = ___CAST(___F32*,___BODY(___arg4));
float* direction = ___CAST(___F32*,___BODY(___arg5));

GLint light = GL_LIGHT0 + ___arg1;
const float dir[] = {direction[0], direction[1], direction[2], 0.0};
glLightfv(light, GL_POSITION, dir);
glLightfv(light, GL_AMBIENT, ambient);
glLightfv(light, GL_DIFFUSE, diffuse);
glLightfv(light, GL_SPECULAR, specular);

glEnable(light);
c-gl-setup-light-end
) light-count ambient diffuse specular direction))
    (+ 1 light-count))

(define-method (gl-setup-light! ctx (light PointLight) light-count)
  (with-access light (PointLight ambient diffuse specular position att-constant att-linear att-quadratic)
    ((c-lambda (int scheme-object scheme-object scheme-object scheme-object float float float) void 
#<<c-gl-setup-light-end
float* ambient  = &(___F32VECTORREF(___arg2, 0));
float* diffuse  = &(___F32VECTORREF(___arg3, 0));
float* specular = &(___F32VECTORREF(___arg4, 0));
float* position = &(___F32VECTORREF(___arg5, 0));

GLint light = GL_LIGHT0 + ___arg1;
const float pos[] = {position[0], position[1], position[2], 1.0};
glLightfv(light, GL_POSITION, pos);
glLightfv(light, GL_AMBIENT, ambient);
glLightfv(light, GL_DIFFUSE, diffuse);
glLightfv(light, GL_SPECULAR, specular);

glLightf(light, GL_CONSTANT_ATTENUATION, ___arg6);
glLightf(light, GL_LINEAR_ATTENUATION, ___arg7);
glLightf(light, GL_QUADRATIC_ATTENUATION, ___arg8);

glEnable(light);
c-gl-setup-light-end
) light-count ambient diffuse specular position att-constant att-linear att-quadratic))
    (+ 1 light-count))

(define stack-height 
  (c-lambda () int "glGetIntegerv(GL_MAX_MODELVIEW_STACK_DEPTH, &___result);"))

;;; shaders

;; (define shader-programs
;;   (list
;;     (list 'blue
;; #<<BLUE-VERT-END
;; void main () {
;;   gl_Position = ftransform();         
;; }
;; BLUE-VERT-END
;; #<<BLUE-FRAG-END
;; void main () {
;;   gl_FragColor = vec4(0., 0. , 1. ,1. );
;; }
;; BLUE-FRAG-END
;; )
;; ))

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
const GLint gl_attrib_types[]           = {GL_UNSIGNED_BYTE, GL_UNSIGNED_SHORT, 
                                           GL_UNSIGNED_INT, GL_SHORT, GL_INT, 
                                           GL_FLOAT, GL_DOUBLE};

float m[16] = {1.0, 0.0, 0.0, 0.0,
               0.0, 1.0, 0.0, 0.0,
               0.0, 0.0, 1.0, 0.0,
               0.0, 0.0, 0.0, 1.0};

float m_rot[9] = {1.0, 0.0, 0.0,
                  0.0, 1.0, 0.0,
                  0.0, 0.0, 1.0};

struct GLAttribute {
  GLint gl_type;
  GLint elm_size;
  GLint elm_count;
  void* data;
};

GLAttribute make_gl_attribute(GLint gl_type, GLint elm_size, GLint elm_count, void* data) {
    GLAttribute attr;
    attr.gl_type = gl_type;
    attr.elm_size = elm_size;
    attr.elm_count = elm_count;
    attr.data = data;
    return attr;
}

struct GLMesh {
  GLAttribute indices, vertices, normals, uvs, colors;
};

GLMesh make_gl_mesh() {
  GLMesh m;
  memset(&m, 0x0, sizeof(GLMesh));
  return m;
}

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
        (with-access image (Image width height format c-data)
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
  (c-lambda (int int int int int int DataBlock) void
#<<apply-mesh-vbo-end

glBindTexture(GL_TEXTURE_2D, ___arg6);

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

if (___arg5) {
  glEnableClientState(GL_COLOR_ARRAY); 
  glBindBuffer(GL_ARRAY_BUFFER, ___arg5);
  glColorPointer(3, GL_FLOAT, 0, 0);
  glEnable(GL_COLOR_MATERIAL);
  CHECK_FOR_GL_ERROR();
}
else {
    const float c_amb[4] = {.8f, .8f, .8f, 1.0f};
    const float c_diff[4] = {.8f, .8f, .8f, 1.0f};
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, c_amb);
    glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, c_diff);
    glDisable(GL_COLOR_MATERIAL);
}

glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ___arg1);  
glDrawElements(GL_TRIANGLES, ___arg7->GetSize(), GL_UNSIGNED_INT, 0);
CHECK_FOR_GL_ERROR();

glDisableClientState(GL_VERTEX_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glDisableClientState(GL_NORMAL_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glDisableClientState(GL_COLOR_ARRAY);
glBindTexture(GL_TEXTURE_2D, 0);
glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
glBindBuffer(GL_ARRAY_BUFFER, 0);

apply-mesh-vbo-end
))
    
(define gl-apply-mesh
  (c-lambda (GLMesh int) void
#<<apply-mesh-end

GLMesh mesh = ___arg1;
if (___arg2) {
  //printf("binding tid: %x\n", ___arg2);
  glBindTexture(GL_TEXTURE_2D, ___arg2);
}
else {
  glBindTexture(GL_TEXTURE_2D, 0);
}

GLAttribute vs = mesh.vertices;
glEnableClientState(GL_VERTEX_ARRAY);
glVertexPointer(vs.elm_size, vs.gl_type, 0, vs.data);
CHECK_FOR_GL_ERROR();

GLAttribute ns = mesh.normals;
if (ns.data) {
  glEnableClientState(GL_NORMAL_ARRAY);
  glNormalPointer(ns.gl_type, 0, ns.data);
}

GLAttribute uvs = mesh.uvs;
if (uvs.data) {
  //printf("using uvs: %x\n", ___arg4);
  glClientActiveTexture(GL_TEXTURE0);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(uvs.elm_size, uvs.gl_type, 0, uvs.data);
}

GLAttribute cols = mesh.colors;
if (cols.data) {
  //printf("using colors: %x\n", ___arg5);
  glEnableClientState(GL_COLOR_ARRAY);
  glColorPointer(cols.elm_size, cols.gl_type, 0, cols.data);
  glEnable(GL_COLOR_MATERIAL);
}
else {
    const float c_amb[4] = {.8f, .8f, .8f, 1.0f};
    const float c_diff[4] = {.8f, .8f, .8f, 1.0f};
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, c_amb);
    glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, c_diff);
}

GLAttribute is = mesh.indices;
glDrawElements(GL_TRIANGLES, is.elm_count, is.gl_type, is.data);
CHECK_FOR_GL_ERROR();

glDisable(GL_COLOR_MATERIAL);
glDisableClientState(GL_VERTEX_ARRAY);
glDisableClientState(GL_TEXTURE_COORD_ARRAY);
glDisableClientState(GL_NORMAL_ARRAY);
glDisableClientState(GL_COLOR_ARRAY);
glBindTexture(GL_TEXTURE_2D, 0);

apply-mesh-end
))

;; (define gl-apply-mesh
;;   (c-lambda (DataBlock DataBlock DataBlock DataBlock DataBlock int) void
;; #<<apply-mesh-end


;; if (___arg6) {
;;   //printf("binding tid: %x\n", ___arg6);
;;   glBindTexture(GL_TEXTURE_2D, ___arg6);
;; }
;; else {
;;   glBindTexture(GL_TEXTURE_2D, 0);
;; }

;; glEnableClientState(GL_VERTEX_ARRAY);
;; glVertexPointer(___arg2->GetDimension(), ___arg2->GetType(), 0, ___arg2->GetVoidDataPtr());
;; CHECK_FOR_GL_ERROR();

;; if (___arg3) {
;;   //printf("using normals: %x\n", ___arg3);
;;   glEnableClientState(GL_NORMAL_ARRAY);
;;   glNormalPointer(GL_FLOAT, 0, ___arg3->GetVoidDataPtr());
;; }

;; if (___arg4) {
;;   //printf("using uvs: %x\n", ___arg4);
;;   glClientActiveTexture(GL_TEXTURE0);
;;   glEnableClientState(GL_TEXTURE_COORD_ARRAY);
;;   glTexCoordPointer(___arg4->GetDimension(), GL_FLOAT, 0, ___arg4->GetVoidDataPtr());
;; }

;; if (___arg5) {
;;   //printf("using colors: %x\n", ___arg5);
;;   glEnableClientState(GL_COLOR_ARRAY);
;;   glColorPointer(___arg5->GetDimension(), GL_FLOAT, 0, ___arg5->GetVoidDataPtr());
;;   glEnable(GL_COLOR_MATERIAL);
;; }
;; else {
;;     const float c_amb[4] = {.8f, .8f, .8f, 1.0f};
;;     const float c_diff[4] = {.8f, .8f, .8f, 1.0f};
;;     glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, c_amb);
;;     glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, c_diff);
;; }

;; glDrawElements(GL_TRIANGLES, ___arg1->GetSize(), ___arg1->GetType(), ___arg1->GetVoidData());
;; CHECK_FOR_GL_ERROR();

;; glDisable(GL_COLOR_MATERIAL);
;; glDisableClientState(GL_VERTEX_ARRAY);
;; glDisableClientState(GL_TEXTURE_COORD_ARRAY);
;; glDisableClientState(GL_NORMAL_ARRAY);
;; glDisableClientState(GL_COLOR_ARRAY);
;; glBindTexture(GL_TEXTURE_2D, 0);

;; apply-mesh-end
;; ))

(define (gl-push-transformation trans)
  (set-gl-matrix! trans)
  ((c-lambda () void
     "glPushMatrix(); glMultMatrixf(m);")
   ))

(define gl-pop-transformation
  (c-lambda () void
    "glPopMatrix();"))

(define gl-viewport
  (c-lambda (int int) void
    "glViewport(0,0,___arg1,___arg2);
     CHECK_FOR_GL_ERROR();"))

(define gl-clear
  (c-lambda () void
    "glClearColor(.8,1.0,1.0,1.0);
     glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
     CHECK_FOR_GL_ERROR();"))

(define gl-viewing-volume
  (c-lambda ((pointer float)) void
#<<GL-VIEWING-VOLUME-END
  float* proj = ___arg1;
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glMultMatrixf(proj);
  CHECK_FOR_GL_ERROR();
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glMultMatrixf(m);
  CHECK_FOR_GL_ERROR();
GL-VIEWING-VOLUME-END
))

;; --- skinning ---
;; (maybe this kind of skinning should be moved to animation.scm since
;; it is not gl specific.
(define init-skin-mesh
  (c-lambda (GLMesh) void
#<<c-init-skin-mesh-end

GLAttribute verts = ___arg1.vertices;
GLAttribute norms = ___arg1.normals;

memset(verts.data, 0x0, sizeof(float) * verts.elm_size * verts.elm_count);
memset(norms.data, 0x0, sizeof(float) * norms.elm_size * norms.elm_count);
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
  (c-lambda (GLMesh
             (pointer void) ;; src-verts
             (pointer void) ;; src-norms
             Weights)  ;; vertex weights
      void 
#<<c-skin-mesh-end

GLAttribute verts = ___arg1.vertices;
GLAttribute norms = ___arg1.normals;

float* src_verts = (float*)___arg2;
float* src_norms = (float*)___arg3;
float* dest_verts = (float*)verts.data;
float* dest_norms = (float*)norms.data;

vector<pair<unsigned int, float> >::iterator itr = ___arg4->begin();
for (; itr != ___arg4->end(); ++itr) {
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

;; construct column major float array matrices from transformation.
(define (set-gl-rotation-matrix! trans)
  (quat-deref (Transformation-rotation trans)
    (c-lambda (float float float float) void
#<<UPDATE_C_MATRIX_END
const float w  = ___arg1;
const float x  = ___arg2;
const float y  = ___arg3;
const float z  = ___arg4;

// first column
m_rot[0] = 1-2*y*y-2*z*z;
m_rot[1] = 2*x*y+2*w*z;
m_rot[2] = 2*x*z-2*w*y;

// second column
m_rot[3] = 2*x*y-2*w*z;
m_rot[4] = 1-2*x*x-2*z*z;
m_rot[5] = 2*y*z+2*w*x;

// third column
m_rot[6]  = 2*x*z+2*w*y;
m_rot[7]  = 2*y*z-2*w*x;
m_rot[8] = 1-2*x*x-2*y*y;

UPDATE_C_MATRIX_END
)))

;; the view matrix is the inverse matrix of the camera transformation
(define (set-gl-view-matrix! trans)
  (quat-deref (Transformation-rotation trans)
    (c-lambda (float float float float) void
#<<UPDATE_C_MATRIX_END
const float w  = ___arg1;
const float x  = ___arg2;
const float y  = ___arg3;
const float z  = ___arg4;

// first column
m[0] = 1-2*y*y-2*z*z;
m[1] = 2*x*y-2*w*z;
m[2]  = 2*x*z+2*w*y;

// second column
m[4] = 2*x*y+2*w*z;
m[5] = 1-2*x*x-2*z*z;
m[6]  = 2*y*z-2*w*x;

// third column
m[8] = 2*x*z-2*w*y;
m[9] = 2*y*z+2*w*x;
m[10] = 1-2*x*x-2*y*y;

UPDATE_C_MATRIX_END
))
  (vec-deref (Transformation-translation trans)
    (c-lambda (float float float) void
#<<UPDATE_TRANSFORMATION_POS_END

const float x  = ___arg1;
const float y  = ___arg2;
const float z  = ___arg3;

// fourth column
m[12] = -x;
m[13] = -y;
m[14] = -z;
UPDATE_TRANSFORMATION_POS_END
)))


(define (set-gl-matrix! transformation)
  (with-access transformation (Transformation translation rotation scaling pivot)
    (quat-deref rotation set-gl-matrix-rotation!)
    (if pivot
        (set-gl-matrix-position-with-pivot! (vec-ref translation 0)
                                            (vec-ref translation 1)
                                            (vec-ref translation 2)
                                            (vec-ref pivot 0)
                                            (vec-ref pivot 1)
                                            (vec-ref pivot 2))
        (set-gl-matrix-position! (vec-ref translation 0)
                                 (vec-ref translation 1)
                                 (vec-ref translation 2)))
    (set-gl-matrix-scaling! (vec-ref scaling 0)
                            (vec-ref scaling 1)
                            (vec-ref scaling 2))))

(define set-gl-matrix-rotation!
  (c-lambda (float float float float) void
#<<UPDATE_C_MATRIX_END
const float w  = ___arg1;
const float x  = ___arg2;
const float y  = ___arg3;
const float z  = ___arg4;

// first column
m[0] = 1-2*y*y-2*z*z;
m[1] = 2*x*y+2*w*z;
m[2] = 2*x*z-2*w*y;

// second column
m[4] = 2*x*y-2*w*z;
m[5] = 1-2*x*x-2*z*z;
m[6] = 2*y*z+2*w*x;

// third column
m[8]  = 2*x*z+2*w*y;
m[9]  = 2*y*z-2*w*x;
m[10] = 1-2*x*x-2*y*y;

UPDATE_C_MATRIX_END
))

(define set-gl-matrix-position-with-pivot!
  (c-lambda (float float float float float float) void
#<<UPDATE_TRANSFORMATION_PIVOT_END
const float x  = ___arg1;
const float y  = ___arg2;
const float z  = ___arg3;
const float px = ___arg4;
const float py = ___arg5;
const float pz = ___arg6;
const float dx = x - px;
const float dy = y - py;
const float dz = z - pz;

// fourth column
m[12] = ((m[0] - 1.0) * dx +  m[4] * dy         +  m[8] * dz          + x);
m[13] =  (m[1] * dx        + (m[5] - 1.0) * dy  +  m[9] * dz          + y);
m[14] =  (m[2] * dx        +  m[6] * dy         + (m[10] - 1.0) * dz  + z);
UPDATE_TRANSFORMATION_PIVOT_END
))

(define set-gl-matrix-position!
  (c-lambda (float float float) void
#<<UPDATE_TRANSFORMATION_POS_END

const float x  = ___arg1;
const float y  = ___arg2;
const float z  = ___arg3;

// fourth column
m[12] = x;
m[13] = y;
m[14] = z;
UPDATE_TRANSFORMATION_POS_END
))

(define set-gl-matrix-scaling!
  (c-lambda (float float float) void
#<<UPDATE_TRANSFORMATION_ROT_AND_SCL_END
const float sx = ___arg1;
const float sy = ___arg2;
const float sz = ___arg3;

// first column
m[0] *= sx;
m[1] *= sy;
m[2] *= sz;

// second column
m[4] *= sx;
m[5] *= sy;
m[6] *= sz;

// third column
m[8]  *= sx;
m[9]  *= sy;
m[10] *= sz;
UPDATE_TRANSFORMATION_ROT_AND_SCL_END
))
