(c-declare #<<c-declare-end
#include <Resources/Texture2D.h>
#include <Resources/ResourceManager.h>
#include <Resources/SDLImage.h>

using namespace OpenEngine::Resources;
c-declare-end
)

((c-lambda () void
"ResourceManager<ITexture2D>::AddPlugin(new SDLImagePlugin());"
))

(c-define-type CharArray (pointer "char"))

;; --- Bitmap ---
(define-class Bitmap Object
  ([= width  :immutable :initializer (lambda () 0)]
   [= height :immutable :initializer (lambda () 0)]
   [= c-data :immutable :initializer (c-lambda () CharArray "___result_voidstar = NULL;")]))

(define-method (initialize! (o Bitmap))
  ;; free the c-matrix when object is reclaimed by the gc.
  (make-will o (lambda (x) 
   		 ;; (display "delete array\n")
		 (with-access x (Bitmap c-data)
	           ((c-lambda (CharArray) void
		      "if (___arg1) delete[] ___arg1;")
		   c-data))))
  (call-next-method))

(define *loaded-bitmap* #f)

(c-define (set-bitmap width height data)
    (int int CharArray) void "set_bitmap_scm" ""
    (set! *loaded-bitmap* (instantiate Bitmap :width width :height height :c-data data)))

(define c-load-bitmap
  (c-lambda (char-string) bool
#<<c-load-bitmap-end

ITexture2DPtr texr = ResourceManager<ITextureResource>::Create(___arg1);
texr->Load();
unsigned int size = texr->GetChannels() * texr->GetChannelSize() * texr->GetWidth() * texr->GetHeight();
char* data = new char[size];

// copy the texture data since texr boost pointer goes out of scope and deletes the internal data array.
memcpy(data, texr->GetVoidDataPtr(), size);
printf("load-bitmap path: %s width: %d height: %d\n", ___arg1, texr->GetWidth(), texr->GetHeight());
set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), data);
texr->Unload();
c-load-bitmap-end
))

(define (load-bitmap path)
  (if (c-load-bitmap path)
      (let ([bitmap *loaded-bitmap*])
	(set! *loaded-bitmap* #f)
	bitmap)
      #f))
  

;; --- Texture ---
;; todo: add texture header, such as clamping, mipmapping ...
(define-class Texture Object
  ([= image  :initializer (lambda () (instantiate Bitmap))]))
   