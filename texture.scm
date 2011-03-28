(c-declare #<<c-declare-end
#include <Resources/Texture2D.h>
#include <Resources/ResourceManager.h>
//#include <Resources/SDLImage.h>
#include <Resources/FreeImage.h>
using namespace OpenEngine::Resources;
c-declare-end
)

((c-lambda () void
;;"ResourceManager<ITexture2D>::AddPlugin(new SDLImagePlugin());"
"ResourceManager<ITexture2D>::AddPlugin(new FreeImagePlugin());"
))

;; --- Bitmap ---
(define-class Bitmap Object
  ([= width  :immutable]
   [= height :immutable]
   [= format :immutable]
   [= c-data :immutable :initializer (c-lambda () (pointer char) "___result_voidstar = NULL;")]))

(define-method (initialize! (o Bitmap))
  ;; free the c-matrix when object is reclaimed by the gc.
  (make-will o (lambda (x) 
   		 ;; (display "delete array\n")
		 (with-access x (Bitmap c-data)
	           ((c-lambda ((pointer char)) void
		      "if (___arg1) delete[] ___arg1;")
		   c-data))))
  (call-next-method))

(define *loaded-bitmap* #f)

(c-define (set-bitmap width height format data)
    (int int char-string (pointer char)) void "set_bitmap_scm" ""
    (set! *loaded-bitmap* (instantiate Bitmap 
                              :width width 
                              :height height 
                              :format (string->symbol format) 
                              :c-data data)))

(define c-load-bitmap
  (c-lambda (char-string) bool
#<<c-load-bitmap-end
ITexture2DPtr texr = ResourceManager<ITextureResource>::Create(___arg1);
texr->Load();
unsigned int size = texr->GetChannels() * texr->GetChannelSize() * texr->GetWidth() * texr->GetHeight();
char* data = new char[size];

// copy the texture data since texr boost pointer goes out of scope and deletes the internal data array.
memcpy(data, texr->GetVoidDataPtr(), size);
// printf("load-bitmap path: %s width: %d height: %d\n", ___arg1, texr->GetWidth(), texr->GetHeight());

switch (texr->GetColorFormat()) {
  case RGB:  set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), "rgb", data); break;
  case RGBA: set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), "rgba", data); break;
  case BGR:  set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), "bgr", data); break;
  case BGRA: set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), "bgra", data); break;
  default:   set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), "unknown", data); break;
}
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
  ([= image :immutable]
   [= wrapping-s :immutable :initializer (lambda () 'clamp)]
   [= wrapping-t :immutable :initializer (lambda () 'clamp)]))
