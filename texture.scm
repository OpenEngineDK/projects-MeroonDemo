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


;; --- Bitmap ---
(define-class Bitmap Object
  ([= width  :immutable :initializer (lambda () 0)]
   [= height :immutable :initializer (lambda () 0)]
   [= c-data :maybe-uninitialized]))


(define *loaded-bitmap* #f)

(c-define-type CharArray (pointer "char"))

(c-define (set-bitmap width height data)
    (int int CharArray) void "set_bitmap_scm" ""
    (display "in set-bitmap\n")
    (set! *loaded-bitmap* (instantiate Bitmap :width width :height height :c-data data)))

(define c-load-bitmap
  (c-lambda (char-string) bool
#<<c-load-bitmap-end

printf("load path: %s\n", ___arg1);
ITexture2DPtr texr = ResourceManager<ITextureResource>::Create(___arg1);
texr->Load();
unsigned int size = texr->GetChannels() * texr->GetChannelSize() * texr->GetWidth() * texr->GetHeight();
char* data = new char[size];
memcpy(data, texr->GetVoidDataPtr(), size);
printf("load-bitmap width: %d height: %d data %x\n", texr->GetWidth(), texr->GetHeight(), (char*)texr->GetVoidDataPtr());
set_bitmap_scm(texr->GetWidth(), texr->GetHeight(), data);
printf("after set-bitmap\n");
texr->Unload();
printf("end of load-bitmap\n");
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
   