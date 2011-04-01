(c-declare #<<c-declare-end
#include <cstdio>
#include <Meta/OpenGL.h>
c-declare-end
)

;; Shader
(define-class OpenGLShader Object
  ([= vertexProgram    ;; char-string
      :immutable]
   [= fragmentProgram  ;; char-string
      :immutable]
   [= programId        ;; GLuint
      :initializer (c-lambda () unsigned-int "___result = 0;")]))

(define (make-OpenGLShader-from-string vertProg fragProg)
  (instantiate OpenGLShader
	       :vertexProgram vertProg
	       :fragmentProgram fragProg))

(define (OpenGLShader-add-destructor shader)
  (make-will shader 
	     (lambda (s) 
	       (with-access shader (OpenGLShader programId)
		 ((c-lambda (unsigned-int) void 
#<<c-destroy-shader
GLuint programID = ___arg1;
if (programID)
  glDeleteProgram(programID);
  //@TODO probably also delete individual shader programs
c-destroy-shader
		    ) programId)))))



(define-method (initialize! (shader OpenGLShader))
  (with-access shader (OpenGLShader vertexProgram fragmentProgram programId)
    (set! programId ((c-lambda (char-string char-string) unsigned-int
#<<c-init-gl-shader
// Create vertex shader
const GLchar* vert = ___arg1;
GLuint vId = glCreateShader(GL_VERTEX_SHADER);
glShaderSource(vId, 1, &vert, NULL);
glCompileShader(vId);

// Error checking
GLint compiled;
glGetShaderiv(vId, GL_COMPILE_STATUS, &compiled);
if (!compiled) {
  printf("failed to compile vertex program: \n%s\n",___arg1);
  GLsizei bufsize;
  const int maxBufSize = 100;
  char buffer[maxBufSize];
  glGetShaderInfoLog(vId, maxBufSize, &bufsize, buffer);
  printf("Compile errors: %s\n",buffer);
}

const GLchar* frag = ___arg2;
GLuint fId = glCreateShader(GL_FRAGMENT_SHADER);
glShaderSource(fId, 1, &vert, NULL);
glCompileShader(fId);

// Error checking
glGetShaderiv(fId, GL_COMPILE_STATUS, &compiled);
if (!compiled) {
  printf("failed to compile fragment program: \n%s\n",___arg2);
  GLsizei bufsize;
  const int maxBufSize = 100;
  char buffer[maxBufSize];
  glGetShaderInfoLog(fId, maxBufSize, &bufsize, buffer);
  printf("Compile errors: %s\n",buffer);
}

GLuint programId = glCreateProgram();
glAttachShader(programId, vId);
glAttachShader(programId, fId);

glLinkProgram(programId);
GLint linked;
glGetProgramiv(programId, GL_LINK_STATUS, &linked);
if (!linked) {
  printf("Failed to link program.\n");
}

return programId;
c-init-gl-shader
		       ) vertexProgram fragmentProgram))
    (OpenGLShader-add-destructor shader)))

;; *** ATTRIBUTE functions ***

(define (OpenGLShader-get-attribute-location shader name)
  (with-access shader (OpenGLShader programId)
    ((c-lambda (unsigned-int char-string) int
#<<c-get-attr-loc
GLint loc = glGetAttribLocation(___arg1, ___arg2);
CHECK_FOR_GL_ERROR();
if (loc == -1)
  printf("Attribute not found: %s", ___arg2);
return loc;
c-get-attr-loc
       ) programId name)))

;; *** UNIFORM functions ***

(define (OpenGLShader-set-uniform-3f shader name value)
  (with-access shader (OpenGLShader programId)
    ((c-lambda (unsigned-int char-string float float float) void
#<<c-set-uniform-3f
       GLuint programID = ___arg1;
       GLchar* name = ___arg2;
       float data[] = {___arg3, ___arg4, ___arg5};
       GLint loc = glGetUniformLocation(programID, name);
       CHECK_FOR_GL_ERROR();
       if (loc == -1)
         printf("Uniform not found: %s\n", name);

       glUniform3fv(loc, 3, data);
       CHECK_FOR_GL_ERROR();
       printf("Applied [%f, %f, %f] to %s", ___arg3, ___arg4, ___arg5, ___arg2);
c-set-uniform-3f
       ) programId name (car value) (cadr value) (caddr value))))

