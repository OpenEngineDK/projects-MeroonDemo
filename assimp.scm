(c-declare #<<c-declare-end
#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags
#include <Resources/DataBlock.h>
using namespace OpenEngine::Resources;

void readMeshes(aiMesh** ms, unsigned int size);
void readScene(const aiScene* scene);

c-declare-end
)

(c-define-type DataBlock (pointer "IDataBlock"))

(define *loaded-blocks* '())
(define *loaded-meshes* '())
(define *scene-root* (instantiate SceneParent))
(define *scene-parent* *scene-root*)

(define *transformation-pos* (make-vector 3 0.0))
(define *transformation-rot* (instantiate Quaternion))
(define *transformation-scale* (make-vector 3 1.0))

(c-define (add-vertex-db db)
    (DataBlock) void "add_vertex_db_scm" ""
    (set! *loaded-blocks* (cons (cons 'vertices db) *loaded-blocks*)))

(c-define (add-index-db db)
    (DataBlock) void "add_index_db_scm" ""
    (set! *loaded-blocks* (cons (cons 'indices db) *loaded-blocks*)))


(c-define (add-mesh)
    () void "add_mesh_scm" ""
    (display "add-mesh!")
    (set! *loaded-meshes* (cons *loaded-blocks* *loaded-meshes*))
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

(c-define (append-transformation-node)
    () void "append_transformation_node_scm" ""
    (let ((node (instantiate TransformationNode 
			     :transformation (instantiate Transformation 
							  :translation *transformation-pos*
                                                          :rotation *transformation-rot*
							  :scaling *transformation-scale*))))
      (with-access *scene-parent* (SceneParent children)
		   (set! children (cons node children)))
      (set! *scene-parent* node)))

(c-define (append-mesh-node i)
    (int) void "append_mesh_node_scm" ""
    (display "append-mesh-node!")
    (with-access *scene-parent* (SceneParent children)
		 (set! children 
		       (cons 
			 (instantiate MeshNode 
				      :geotype 'triangles
				      :datablocks (list-ref *loaded-meshes* i))
			 children))))


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
  readMeshes(scene->mMeshes, scene->mNumMeshes);
  readScene(scene);
  ___result = true;
}
c-load-scene-end
))


(define (load-scene path)
  (set! *scene-root* (instantiate SceneParent))
  (set! *scene-parent* *scene-root*)
  (if (c-load-scene path)
      (begin
	(pretty-print "yes-hest")
	*scene-root*)
      (begin
	(pretty-print "no-hest")
	#f)))

