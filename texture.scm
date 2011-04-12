(c-declare #<<c-declare-end
#include <Resources/Texture2D.h>
#include <Resources/ResourceManager.h>
#include <FreeImage.h>
using namespace OpenEngine::Resources;
c-declare-end
)

;; --- Image ---
(define-class Image Object
  ([= width  :immutable]
   [= height :immutable]
   [= format :immutable]
   [= c-data :immutable]))

(define-method (initialize! (o Image))
  ;; free the c-matrix when object is reclaimed by the gc.
  (make-will o (lambda (x) 
   		 ;; (display "delete array\n")
		 (with-access x (Image c-data)
	           ((c-lambda ((pointer char)) void
		      "if (___arg1) delete[] ___arg1;")
		   c-data))))
  (call-next-method))

(define *loaded-bitmap* #f)

(c-define (set-bitmap width height format data)
    (int int char-string (pointer char)) void "set_bitmap_scm" ""
    (set! *loaded-bitmap* (instantiate Image 
                              :width width 
                              :height height 
                              :format (string->symbol format) 
                              :c-data data)))

(define c-load-bitmap
  (c-lambda (char-string) bool
#<<c-load-bitmap-end

FREE_IMAGE_FORMAT formato = FreeImage_GetFileType(___arg1, 0);
FIBITMAP* img = FreeImage_Load(formato, ___arg1);
if (!img) {
    ___result = false;
}
else {
// color types:
// 'uint8   : one channel 8 bit int
// 'uint16  : one channel 16 bit int
// 'float32 : one channel 32 bit float
// 'rgb565  : 16 bit rgb color
// 'rgb     : 24 bit rgb color
// 'rgba    : 32 bit rgba color
// 'rgb32f  : 3 x 32 bit float color  
// 'rgba32f : 4 x 32 bit float color  


    unsigned int width  = FreeImage_GetWidth(img);
    unsigned int height = FreeImage_GetHeight(img);
    unsigned int pixels = width * height;
    BYTE *bits = FreeImage_GetBits(img);
    unsigned int bpp = FreeImage_GetBPP(img);
    FREE_IMAGE_TYPE image_type = FreeImage_GetImageType(img);
    bool loaded = true;

    unsigned int i;
    switch(image_type) {
        case FIT_BITMAP: 
        {
            switch(bpp) {
                case 8:
                {
                    char* data = new char[pixels];
                    memcpy(data, bits, sizeof(char) * pixels); 
                    set_bitmap_scm(width, height, "uint8", data); 
                    break;
                }
                case 24: // we could also use 'RGBTRIPLE color' here
                {
                    char* data = new char[pixels*3];
                    RGBTRIPLE* pix = (RGBTRIPLE*) bits;
                    for (i = 0; i < pixels; ++i) {
                        data[i*3]   = pix[i].rgbtRed;
                        data[i*3+1] = pix[i].rgbtGreen;
                        data[i*3+2] = pix[i].rgbtBlue;
                    }
                    set_bitmap_scm(width, height, "rgb", data);
                    break;
                }
                case 32:
                {
                    char* data = new char[pixels*4];
                    RGBQUAD* pix = (RGBQUAD*) bits;
                    for (i = 0; i < pixels; ++i) {
                        data[i*4]   = pix[i].rgbRed;
                        data[i*4+1] = pix[i].rgbGreen;
                        data[i*4+2] = pix[i].rgbBlue;
                        data[i*4+3] = pix[i].rgbReserved;
                    }
                    set_bitmap_scm(width, height, "rgba", data);
                    break;
                }
                default:
                    loaded = false;
            }
            break;   
        }
        case FIT_UINT16:
        {
            unsigned short* data = new (unsigned short)(pixels);
            memcpy(data, bits, sizeof(unsigned short) * pixels); 
            set_bitmap_scm(width, height, "uint16", (char*)data); 
            break;
        }
        case FIT_FLOAT:
            {
                float* data = new float[pixels];
                memcpy(data, bits, sizeof(float) * pixels); 
                set_bitmap_scm(width, height, "float32", (char*)data); 
                break;
            }
        default:
            loaded = false;
    }
    FreeImage_Unload(img);
    ___result = loaded;
}        
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
