(c-declare #<<c-declare-end
#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags
#include <cstdio>

#include <vector>

//using namespace OpenEngine::Resources;
using namespace std;
void readLights(aiLight**, unsigned int);
void readMaterials(aiMaterial**, unsigned int);
void readMeshes(aiMesh**, unsigned int);
void readAnimations(aiAnimation**, unsigned int size);
void readScene(const aiScene*);

typedef vector<pair<unsigned int,float> > Weights;

c-declare-end
)

;;(c-define-type DataBlock (pointer "IDataBlock"))
(c-define-type Weights (pointer "Weights"))

(define *current-file-dir* #f)

;; scene globals
(define *scene-root* #f)
(define *scene-parent-stack* #f)

;; geometry globals
(define *loaded-blocks* '())
(define *loaded-meshes* '())
(define *loaded-lights* '())
(define *loaded-materials* '())

;; transformation globals
(define *transformation-pos* (make-vec 3 0.0))
(define *transformation-rot* (make-quat))
(define *transformation-scale* (make-vec 3 1.0))

;; animation globals
(define *loaded-bones* '())
(define *loaded-transformations* '())
(define *position-keys* '())
(define *rotation-keys* '())
(define *scaling-keys* '())
(define *bone-animations* '())
(define *mesh-keys* '())
(define *mesh-animations* '())
(define *animations* '()) ;; contains all the loaded animation handlers


;; --- file operations ---

(define (->file-dir path) 
  (if (string? path)
      (let ([len (string-length path)])
	(letrec ([last-sep (lambda (i r) 
			     (cond
			      [(< i len)
			       (if (equal? (string-ref path i) #\/)
				   (last-sep (+ 1 i) i)
				   (last-sep (+ 1 i) r))]
			      [else r]))])
	  (substring path 0 (+ 1 (last-sep 0 0)))))))


;; --- lights ---
(c-define (add-directional-light ambient diffuse specular direction)
    (scheme-object scheme-object scheme-object scheme-object) void "add_directional_light_scm" ""
  (set! *loaded-lights* (cons (instantiate DirectionalLight
                                  :ambient ambient
                                  :diffuse diffuse
                                  :specular diffuse
                                  :direction direction)
                              *loaded-lights*)))

(c-define (add-point-light ambient diffuse specular position att-constant att-linear att-quadratic)
    (scheme-object scheme-object scheme-object scheme-object float float float) void "add_point_light_scm" ""
  (set! *loaded-lights* (cons (instantiate PointLight
                                  :ambient ambient
                                  :diffuse diffuse
                                  :specular diffuse
                                  :position position
                                  :att-constant att-constant
                                  :att-linear att-linear
                                  :att-quadratic att-quadratic)
                              *loaded-lights*)))

(c-define (push-light-node light-index)
    (int) void "push_light_node_scm" ""
    (let ([l (list-ref *loaded-lights* 
                       (- ;; light-indices were given in reverse order, thats why
                        (length *loaded-lights*) 
                        light-index))])
      (with-access (car *scene-parent-stack*) (SceneNode children)
		   (set! children (cons (instantiate LightLeaf :light l) children)))))


;; --- animation functions ---

;; use make-*-key-vector functions to construct big-ass float32
;; vector.
;;
;; Q: why not use regular vector?
;; A: because GC will traverse each entry in its mark phase, leading
;;    to very long gc times.
;;
;; Q: why use ##still-copy?
;; A: because this tells GC never to relocate the vector, potentially
;;    saving lots of GC-time.

(c-define (make-position-key-vector size)
    (int) void "make_position_key_vector_scm" ""
  (set! *position-keys* (##still-copy (make-vec (* size 4)))))

(c-define (make-rotation-key-vector size)
    (int) void "make_rotation_key_vector_scm" ""
  (set! *rotation-keys* (##still-copy (make-vec (* size 5)))))

(c-define (make-scaling-key-vector size)
    (int) void "make_scaling_key_vector_scm" ""
  (set! *scaling-keys* (##still-copy (make-vec (* size 4)))))

(c-define (add-position-key time x y z i)
    (float32 float32 float32 float32 int) void "add_position_key_scm" ""
  (let ([p (* i 4)])
    (vec-set! *position-keys* p time)
    (vec-set! *position-keys* (+ p 1) x)
    (vec-set! *position-keys* (+ p 2) y)
    (vec-set! *position-keys* (+ p 3) z)))

(c-define (add-rotation-key time w x y z i)
    (float32 float32 float32 float32 float32 int) void "add_rotation_key_scm" ""
  (let ([p (* i 5)])
    (vec-set! *rotation-keys* p time)
    (vec-set! *rotation-keys* (+ p 1) w)
    (vec-set! *rotation-keys* (+ p 2) x)
    (vec-set! *rotation-keys* (+ p 3) y)
    (vec-set! *rotation-keys* (+ p 4) z)))

(c-define (add-scaling-key time x y z i)
    (float32 float32 float32 float32 int) void "add_scaling_key_scm" ""
  (let ([p (* i 4)])
    (vec-set! *scaling-keys* p time)
    (vec-set! *scaling-keys* (+ p 1) x)
    (vec-set! *scaling-keys* (+ p 2) y)
    (vec-set! *scaling-keys* (+ p 3) z)))

(c-define (clear-animation-keys)
    () void "clear_animation_keys_scm" "" 
  (set! *position-keys* '())
  (set! *rotation-keys* '())
  (set! *scaling-keys* '()))

(c-define (add-bone-animation bone-index)
    (int) void "add_bone_animation_scm" ""
  (set! *bone-animations* (cons (instantiate BoneAnimation
                                    :bone (list-ref 
                                           *loaded-bones*  
                                           (- ;; bone-indices were given in reverse order, thats why
                                            (length *loaded-bones*) 
                                            bone-index)) 
                                    :position-keys *position-keys*
                                    :rotation-keys *rotation-keys*
                                    :scaling-keys *scaling-keys*)
                                *bone-animations*))
  (clear-animation-keys))

(c-define (add-transformation-animation trans-index)
    (int) void "add_transformation_animation_scm" ""
  (let ([trans (list-ref 
                *loaded-transformations*  
                (- ;; bone-indices were given in reverse order, thats why
                 (length *loaded-transformations*) 
                 trans-index))])
    (with-access trans (TransformationNode info)
      (set! info "animated\\n"))
    (set! *bone-animations* (cons (instantiate TransformationAnimation
                                      :transformation-node trans
                                      :position-keys  *position-keys*
                                      :rotation-keys *rotation-keys*
                                      :scaling-keys *scaling-keys*)
                                  *bone-animations*))
    (clear-animation-keys)))

(c-define (add-animation name duration ticks-per-second)
    (char-string float float) void "add_animation_scm" ""
  (let ([anims (append *bone-animations* *mesh-animations*)])
    ;; @todo : if only one sub-animation exists, don't wrap it in
    ;;         ParallellAnimation
        (set! *animations* (cons 
                      (instantiate ParallelAnimation
                          :name name
                          :duration duration
                          :ticks-per-second ticks-per-second
                          :child-animations anims)
                      *animations*)))
  (set! *mesh-animations* '())
  (set! *bone-animations* '()))


;; --- geometry loading ---

(c-define (add-vertex-attribute type elm-size elm-count data)
    (char-string int int (pointer void)) void "add_vertex_attribute_scm" ""
    (set! *loaded-blocks* (cons (instantiate VertexAttribute
                                    :elm-type (string->symbol type)
                                    :elm-size elm-size
                                    :elm-count elm-count
                                    :data data)
                                *loaded-blocks*)))

(c-define (add-false-db)
    () void "add_false_db_scm" ""
    (set! *loaded-blocks* (cons #f *loaded-blocks*)))

(c-define (add-mesh material-index)
    (int) void "add_mesh_scm" ""
    (set! *loaded-meshes* (cons 
                           (instantiate Mesh
                               :geotype 'triangles
                               :indices (list-ref *loaded-blocks* 0)
                               :vertices (list-ref *loaded-blocks* 1)
                               :normals (list-ref *loaded-blocks* 2)
                               :uvs (list-ref *loaded-blocks* 3)
                               :texture (list-ref 
                                         *loaded-materials*
                                         material-index))
                           *loaded-meshes*))
    (set! *loaded-blocks* '()))

;; gambit scheme apparently does not have the take function...
(define (list-take l i)
  (letrec ([visit (lambda (l i)
                    (if (zero? i)
                        '()
                        (if (pair? l)
                            (cons (car l) (visit (cdr l) (- i 1)))
                            (if (null? l)
                                (error "list too small")
                                (error "not a list")))))])
    (visit l i)))

(c-define (add-animated-mesh material-index number-of-bones)
    (int int) void "add_animated_mesh_scm" ""
  (set! *loaded-meshes* (cons
                         (instantiate AnimatedMesh
                             ;; mesh attributes
                             :geotype 'triangles
                             :indices (list-ref *loaded-blocks* 0)
                             :vertices (list-ref *loaded-blocks* 1)
                             :normals (list-ref *loaded-blocks* 2)
                             :uvs (list-ref *loaded-blocks* 3)
                             :texture (list-ref *loaded-materials* material-index)

                             ;; bind pose attributes
                             :bind-pose-vertices (list-ref *loaded-blocks* 4)
                             :bind-pose-normals (list-ref *loaded-blocks* 5)
                             :bones (list-take *loaded-bones* number-of-bones))
                         *loaded-meshes*))
  (set! *loaded-blocks* '()))


(c-define (set-pos x y z)
    (float float float) void "set_pos_scm" ""
    (set! *transformation-pos* (vec x y z)))

(c-define (set-rot w x y z)
    (float float float float) void "set_rot_scm" ""
    (set! *transformation-rot* (quat w x y z)))

(c-define (set-scale x y z)
    (float float float) void "set_scale_scm" ""
    (set! *transformation-scale* (vec x y z)))

(c-define (add-bone-node weights)
    (Weights) int "add_bone_node_scm" ""
  (let ([offset (instantiate Transformation
                    :translation *transformation-pos*
                    :rotation *transformation-rot*
                    :scaling *transformation-scale*)])
    ;; (normalize! (Transformation-rotation offset))
    ;; (update-transformation-rot-and-scl! offset)
    ;; (update-transformation-pos! offset)
    (set! *loaded-bones* (cons 
                          (instantiate BoneNode
                              :offset offset
                              :c-weights weights)
                          *loaded-bones*))
    (length *loaded-bones*)))

;; append transformation node to scene parent and push on scene parent stack. 
(c-define (push-transformation-node)
    () int "push_transformation_node_scm" ""
    (let ((node (instantiate 
                    TransformationNode 
                    :transformation (instantiate Transformation 
                                        :translation *transformation-pos*
                                        :rotation *transformation-rot*
                                        :scaling *transformation-scale*))))
      (with-access (car *scene-parent-stack*) (SceneNode children)
        (set! children (cons node children)))
      (set! *scene-parent-stack* (cons node *scene-parent-stack*))
      (set! *loaded-transformations* (cons node *loaded-transformations*))
      (length *loaded-transformations*)))

;; append bone node to scene parent and push on scene parent stack. 
(c-define (push-bone-node bone-index)
    (int) void "push_bone_node_scm" ""
    (let ([node (list-ref *loaded-bones* 
                          (- ;; bone-indices were given in reverse order, thats why
                           (length *loaded-bones*) 
                           bone-index))])
      (with-access node (BoneNode transformation)
        (set! transformation 
              (instantiate Transformation
                  :translation *transformation-pos*
                  :rotation *transformation-rot*
                  :scaling *transformation-scale*)))
      (with-access (car *scene-parent-stack*) (SceneNode children)
		   (set! children (cons node children)))
      (set! *scene-parent-stack* (cons node *scene-parent-stack*))))

(c-define (pop-scene-parent)
    () void "pop_scene_parent_scm" ""
  (set! *scene-parent-stack* (cdr *scene-parent-stack*)))

(c-define (append-mesh-node i)
    (int) void "append_mesh_node_scm" ""
    (with-access (car *scene-parent-stack*) (SceneNode children)
		 (set! children 
		       (cons 
                        (instantiate MeshLeaf 
                            :mesh (list-ref *loaded-meshes* i))
                        children))))

(c-define (append-material path)
    (char-string) void "append_material_scm" ""
    (set! *loaded-materials* 
          (cons (instantiate Texture
                    :image (load-image
                            (string-append *current-file-dir* path)))
                *loaded-materials*)))

(c-define (append-empty-material)
    () void "append_empty_material_scm" ""
    (set! *loaded-materials* (cons #f *loaded-materials*)))


(define c-load-scene
  (c-lambda (char-string) bool
#<<c-load-scene-end
Assimp::Importer importer;
const aiScene* scene = importer.ReadFile( ___arg1, 
					  aiProcess_CalcTangentSpace       | 
					  //aiProcess_FlipUVs              |
					  //aiProcess_FlipWindingOrder     |
					  //aiProcess_MakeLeftHanded       |
					  aiProcess_Triangulate            |
					  aiProcess_JoinIdenticalVertices  |
					  aiProcess_GenSmoothNormals       |
					  aiProcess_SortByPType);

// If the import failed, report it
if( !scene ) {
  ___result = false;
}
else {
  readLights(scene->mLights, scene->mNumLights);
  readMaterials(scene->mMaterials, scene->mNumMaterials);
  readMeshes(scene->mMeshes, scene->mNumMeshes);
  readScene(scene);
  readAnimations(scene->mAnimations, scene->mNumAnimations);
  ___result = true;
}
c-load-scene-end
))

(define (load-scene path)
  (set! *scene-root* (instantiate SceneNode))
  (set! *scene-parent-stack* (list *scene-root*))
  (set! *current-file-dir* (->file-dir path))
  (set! *loaded-blocks* '())
  (set! *loaded-meshes* '())
  (set! *loaded-materials* '())
  (set! *loaded-bones* '())
  (set! *loaded-transformations* '())
  (if (c-load-scene path)
      (let ([root *scene-root*])
        (with-access *scene-root* (SceneNode children)
          (if (= 1 (length children))
              (set! root (car children))))
	;; cleanup globals
	(set! *scene-root* #f)
	(set! *scene-parent-stack* #f)
	(set! *current-file-dir* #f)
	(set! *loaded-blocks* '())
	(set! *loaded-meshes* '())
	(set! *loaded-materials* '())
        (set! *loaded-bones* '())
        (set! *loaded-transformations* '())
	root)
      #f))
