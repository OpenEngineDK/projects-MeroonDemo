;; height map stuff ... should be moved to height-map.scm
(define-class Heightmap Object
  ([= data-width    :immutable]
   [= data-height   :immutable]
   [= xy-scale      :immutable]
   [= height-scale  :immutable]
   [= height-data   :immutable]
   [= color-data    :immutable :initializer (lambda () #f)] ;; maybe this should be left out of the data type?
   [= height-offset :immutable :initializer (lambda () 0.)]))

(define (make-heightmap-from-image height-image color-image height-offset xy-scale height-scale) 
  (let ([height-data #f]
        [image-data #f]
        [size (* (Image-width height-image) (Image-height height-image))])
    (with-access height-image (Image format c-data)
      (cond 
        [(eqv? format 'uint8)
         (set! height-data ((c-lambda ((pointer "char") int float float) (pointer "float")
            "float* dest = new float[___arg2];
             unsigned char* src = (unsigned char*)___arg1;
             for (unsigned int i = 0; i < ___arg2; ++i) {
                 dest[i] = ___arg3 + ___arg4 * (float(src[i]) / float(0xFF));
                 //printf(\"dest[i] = \\%f\\n\", dest[i]);
             }
             ___result_voidstar = dest;") c-data size height-offset height-scale))]
        [(eqv? format 'uint16)
         (set! height-data ((c-lambda ((pointer "char") int float float) (pointer "float")
            "float* dest = new float[___arg2];
             unsigned short* src = (unsigned short*)___arg1;
             for (unsigned int i = 0; i < ___arg2; ++i) {
                 dest[i] = ___arg3 + ___arg4 * (float(src[i]) / float(0xFFFF));
             }
             ___result_voidstar = dest;") c-data size height-offset height-scale))]
        [(eqv? format 'float32)
         (set! height-data ((c-lambda ((pointer "char") int float float) (pointer "float")
            "float* dest = new float[___arg2];
             for (unsigned int i = 0; i < ___arg2; ++i) {
                 dest[i] = ___arg3 + ___arg4 * ___arg1[i];
             }
             ___result_voidstar = dest;") c-data size height-offset height-scale))]
        [else #f]))
    (if color-image
        (with-access color-image (Image width height format c-data)
          (if (and (= width (Image-width height-image)) (= height (Image-height height-image)))
              (if (eqv? format 'rgb)
                  (set! color-data ((c-lambda ((pointer "char") int) (pointer "char")
                                      "unsigned char* dest = new unsigned char[3 * ___arg2];
                                       memcpy(dest, ___arg1, 3 * ___arg2 * sizeof(char));
                                       ___result_voidstar = dest;") c-data size))))))
      (if height-data
          (instantiate Heightmap 
              :data-width (Image-width height-image) 
              :data-height (Image-height height-image)
              :xy-scale xy-scale
              :height-data height-data
              :color-data color-data
              :height-offset height-offset
              :height-scale height-scale)
          #f)))

(c-declare
#<<C-DECLARE-END
#include <Resources/DataBlock.h>
#include <Math/Vector.h>

using namespace OpenEngine::Resources;
using namespace OpenEngine::Math;
C-DECLARE-END
)

(define (Heightmap->Mesh heightmap)
  (with-access heightmap (Heightmap data-width data-height height-data color-data height-offset height-scale xy-scale)
    (let ([vs ((c-lambda (int int float float float (pointer "float")) (pointer void)
#<<HEIGHTMAP-TO-MESH-END
    const unsigned int width  = ___arg1;
    const unsigned int height = ___arg2;
    const float xy_scale      = ___arg3;
    const float height_scale  = ___arg4;
    const float height_offset = ___arg5;
    float* data               = ___arg6;
    const unsigned int size   = width * height;

    const float x_correction = 0.5 * (width-1) * xy_scale;  
    const float y_correction = 0.5 * (height-1) * xy_scale;  
    const float height_correction = 0.5 * height_scale + height_offset;

    float* vs = new float[size*3];
    //DataBlock<3,float>* verts = new DataBlock<3,float>(size, vs);

    for (unsigned int i = 0; i < width; ++i) {
        for (unsigned int j = 0; j < height; ++j) {
            unsigned int base =  i + j * width;
            vs[3 * base]     = float(i) * xy_scale - x_correction;
            vs[3 * base + 1] = data[base] - height_correction;
            vs[3 * base + 2] = float(j) * xy_scale - y_correction; 
        }
    }
    ___result_voidstar = vs;
HEIGHTMAP-TO-MESH-END
) data-width
  data-height
  xy-scale
  height-scale
  height-offset
  height-data)]
          [ns ((c-lambda (int int float (pointer "float")) (pointer void)
#<<HEIGHTMAP-TO-MESH-END
    const unsigned int width  = ___arg1;
    const unsigned int height = ___arg2;
    const float xy_scale      = ___arg3;
    float* data               = ___arg4;
    const unsigned int size   = width * height;

    const float z_scale = 1.; // z_scale always 1.0 since we multiply the scale into the heightmap

    float* ns = new float[size*3];
    //DataBlock<3,float>* norms = new DataBlock<3,float>(size, ns);

    for (unsigned int i = 0; i < width; ++i) {
        for (unsigned int j = 0; j < height; ++j) {
                      
            unsigned int base = i + j * width;

	    const float z0 = data[base];

            const float Az = ( i + 1 < width ) ? (data[base + 1]) : z0;
            const float Bz = ( j + 1 < height ) ? (data[base + width]) : z0;
            const float Cz = ( i - 1 >= 0 ) ? (data[base - 1]) : z0;
            const float Dz = ( j - 1 >= 0 ) ? ( data[base - width]) : z0;
            
            Vector<3,float> v(Cz - Az, 2.0f * (xy_scale / z_scale),  Dz - Bz);
            v.Normalize();
            ns[3 * base]     = v[0];
            ns[3 * base + 1] = v[1];
            ns[3 * base + 2] = v[2]; 
        }
    }
    ___result_voidstar = ns;
HEIGHTMAP-TO-MESH-END
) data-width
  data-height
  xy-scale
  height-data)]
          [cs 
           (if color-data
               ((c-lambda (int int (pointer "char")) (pointer void)
#<<HEIGHTMAP-TO-MESH-END
    const unsigned int width  = ___arg1;
    const unsigned int height = ___arg2;
    unsigned char* data       = (unsigned char*)___arg3;
    const unsigned int size   = width * height;

    float* cs = new float[size * 3];
    //DataBlock<3,float>* colors = new DataBlock<3,float>(size, cs);

    for (unsigned int i = 0; i < width; ++i) {
        for (unsigned int j = 0; j < height; ++j) {
            unsigned int base = i + j * width;
            cs[3 * base]     = float(data[3 * base]) / float(0xFF);
            cs[3 * base + 1] = float(data[3 * base + 1]) / float(0xFF);
            cs[3 * base + 2] = float(data[3 * base + 2]) / float(0xFF);
        } 
    }
    ___result_voidstar = cs;
HEIGHTMAP-TO-MESH-END
) data-width
  data-height
  color-data)
               #f)]
          [is ((c-lambda (int int (pointer "float")) (pointer void)
#<<HEIGHTMAP-TO-MESH-END
    const unsigned int width  = ___arg1;
    const unsigned int height = ___arg2;
    float* data               = ___arg3;
    const unsigned int size   = width * height;

    const unsigned int is_count = (width - 1) * (height - 1) * 6;
    unsigned short* is = new unsigned short[is_count];
    //Indices* indices = new Indices(is_count, is);

    for (unsigned int i = 0; i < (width - 1); ++i) {
        for (unsigned int j = 0; j < (height - 1); ++j) {
            unsigned int base = i + j * (width - 1);
            unsigned int vert_base = i + j * width;
            is[6 * base] = vert_base;
            is[6 * base + 1] = (vert_base + width);
            is[6 * base + 2] = (vert_base + 1);
            is[6 * base + 3] = (vert_base + 1);
            is[6 * base + 4] = (vert_base + width);
            is[6 * base + 5] = (vert_base + width + 1);
        }
    }
    ___result_voidstar = is;
HEIGHTMAP-TO-MESH-END
) data-width
  data-height
  height-data)])
       (instantiate Mesh 
           :indices (instantiate VertexAttribute
                        :elm-type 'uint16
                        :elm-size '1
                        :elm-count (* (- data-width 1) (- data-height 1) 6)
                        :data is)
           :vertices (instantiate VertexAttribute
                        :elm-type 'float32
                        :elm-size '3
                        :elm-count (* data-width data-height)
                        :data vs)
           :normals (instantiate VertexAttribute
                        :elm-type 'float32
                        :elm-size '2
                        :elm-count (* data-width data-height)
                        :data ns)
           :colors (if cs 
                       (instantiate VertexAttribute
                           :elm-type 'float32
                           :elm-size '3
                           :elm-count (* data-width data-height)
                           :data cs)
                       #f)))))

