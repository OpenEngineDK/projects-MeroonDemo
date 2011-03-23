(c-declare #<<c-declare-end
#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags
#include <Resources/DataBlock.h>
#include <cstdio>

using namespace OpenEngine::Resources;

void readMaterials(aiMaterial** ms, unsigned int size);
void readMeshes(aiMesh** ms, unsigned int size);
void readScene(const aiScene* scene);

c-declare-end
)

(c-define-type DataBlock (pointer "IDataBlock"))

(define *current-file-dir* #f)

(define *loaded-blocks* '())
(define *loaded-meshes* '())
(define *loaded-materials* '())
(define *scene-root* #f)
(define *scene-parent-stack* #f)

(define *transformation-pos* (make-vector 3 0.0))
(define *transformation-rot* (instantiate Quaternion))
(define *transformation-scale* (make-vector 3 1.0))

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

(c-define (add-db db)
    (DataBlock) void "add_db_scm" ""
    (set! *loaded-blocks* (cons db *loaded-blocks*)))

(c-define (add-false-db)
    () void "add_false_db_scm" ""
    (set! *loaded-blocks* (cons #f *loaded-blocks*)))


(c-define (add-mesh material-index)
    (int) void "add_mesh_scm" ""
    (set! *loaded-meshes* (cons (cons material-index *loaded-blocks*) *loaded-meshes*))
    (set! *loaded-blocks* '()))

(c-define (set-pos x y z)
    (float float float) void "set_pos_scm" ""
    (set! *transformation-pos* (list->vector `(,x ,y ,z))))

(c-define (set-rot w x y z)
    (float float float float) void "set_rot_scm" ""
    (set! *transformation-rot* (instantiate Quaternion :w w :x x :y y :z z)))  

(c-define (set-scale x y z)
    (float float float) void "set_scale_scm" ""
    (set! *transformation-scale* (list->vector `(,x ,y ,z))))

;; append tnode to scene parent and push tnode on scene parent stack. 
(c-define (push-transformation-node)
    () void "push_transformation_node_scm" ""
    (let ((node (instantiate TransformationNode 
			     :transformation (instantiate Transformation 
							  :translation *transformation-pos*
                                                          :rotation *transformation-rot*
							  :scaling *transformation-scale*))))
      (with-access (car *scene-parent-stack*) (SceneParent children)
		   (set! children (cons node children)))
      (set! *scene-parent-stack* (cons node *scene-parent-stack*))))

(c-define (pop-scene-parent)
    () void "pop_scene_parent_scm" ""
  (set! *scene-parent-stack* (cdr *scene-parent-stack*)))

(c-define (append-mesh-node i)
    (int) void "append_mesh_node_scm" ""
    (with-access (car *scene-parent-stack*) (SceneParent children)
		 (set! children 
		       (cons 
			 (instantiate MeshNode 
			     :geotype 'triangles
			     :indices (list-ref (cdr (list-ref *loaded-meshes* i)) 0)
			     :vertices (list-ref (cdr (list-ref *loaded-meshes* i)) 1)
			     :normals (list-ref (cdr (list-ref *loaded-meshes* i)) 2)
			     :uvs (list-ref (cdr (list-ref *loaded-meshes* i)) 3)
			     :texture (list-ref *loaded-materials* (car (list-ref *loaded-meshes* i))))
			 children))))

(c-define (append-material path)
    (char-string) void "append_material_scm" ""
    (set! *loaded-materials* (cons (instantiate Texture :image (load-bitmap (string-append *current-file-dir* path))) *loaded-materials*)))

(c-define (append-empty-material)
    () void "append_empty_material_scm" ""
    (set! *loaded-materials* (cons (instantiate Texture) *loaded-materials*)))


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
  readMaterials(scene->mMaterials, scene->mNumMaterials);
  readMeshes(scene->mMeshes, scene->mNumMeshes);
  readScene(scene);
  ___result = true;
}
c-load-scene-end
))


(define (load-scene path)
  (set! *scene-root* (instantiate SceneParent))
  (set! *scene-parent-stack* (list *scene-root*))
  (set! *current-file-dir* (->file-dir path))
  (set! *loaded-blocks* '())
  (set! *loaded-meshes* '())
  (set! *loaded-materials* '())
  (if (c-load-scene path)
      (let ([root *scene-root*])
	;; cleanup globals
	(set! *scene-root* #f)
	(set! *scene-parent-stack* #f)
	(set! *current-file-dir* #f)
	(set! *loaded-blocks* '())
	(set! *loaded-meshes* '())
	(set! *loaded-materials* '())
	root)
      #f))
