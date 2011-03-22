(define pi 3.14159265358979323846264338328)

(c-define-type FloatArray (pointer "float"))

(define-class Projection Object
  ([= aspect   :immutable :initializer (lambda () (/ 4.0 3.0))]
   [= fov      :immutable :initializer (lambda () (/ pi 4.0))]
   [= near     :immutable :initializer (lambda () 3.0)]
   [= far      :immutable :initializer (lambda () 3000.0)]
   [= c-matrix :immutable 
      :initializer (c-lambda () FloatArray
		     "float* m = new float[16];
		     ___result_voidstar = m;"
		     )]))

(define (update-proj! o)
  ((c-lambda (float float float float FloatArray) void
#<<UPDATE_PROJECTION_END
float aspect = ___arg1;
float fov    = ___arg2;
float near   = ___arg3;
float far    = ___arg4;
float* m     = ___arg5;

float f = 1.0f / tanf(fov * 0.5f);
float a = (far + near) / (near - far);
float b = (2.0f * far * near) / (near - far);

// first column
m[0] = f / aspect;
m[1] = 0.0f;
m[2] = 0.0f;
m[3] = 0.0f;

// second column
m[4] = 0.0f;
m[5] = f;
m[6] = 0.0f;
m[7] = 0.0f;

// third column
m[8]  = 0.0f;
m[9]  = 0.0f;
m[10] = a;
m[11] = -1.0f;

// fourth column
m[12] = 0.0f;
m[13] = 0.0f;
m[14] = b;
m[15] = 0.0f;
UPDATE_PROJECTION_END
  )
   (Projection-aspect o)
   (Projection-fov o)
   (Projection-near o)
   (Projection-far o)
   (Projection-c-matrix o)))
