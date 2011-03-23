#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags

#include <Resources/DataBlock.h>
#include <cstdio>

#include <set>
#include <string>

using namespace OpenEngine::Resources;
using namespace std;

set<string> bones;

void add_db_scm(IDataBlock* db);
void add_false_db_scm();
void add_mesh_scm(int i);
void set_pos_scm(float x, float y, float z);
void set_rot_scm(float w, float x, float y, float z);
void set_scale_scm(float x, float y, float z);
void push_transformation_node_scm();
void pop_scene_parent_scm();
void append_mesh_node_scm(int i);

void append_material_scm(char* path);
void append_empty_material_scm();

void readMaterials(aiMaterial** ms, unsigned int size) {
    unsigned int i;
    for (i = 0; i < size; ++i) {
        aiMaterial* m = ms[size-i-1];

        aiString path;
        if (AI_SUCCESS == m->Get(AI_MATKEY_TEXTURE(aiTextureType_DIFFUSE, 0), path))
            append_material_scm(path.data);
        else append_empty_material_scm();
    }
}


void readMeshes(aiMesh** ms, unsigned int size) {
    bones.clear();
    unsigned int i, j;
    for (i = 0; i < size; ++i) {
        aiMesh* m = ms[size-i-1]; // iterate in reverse order since we prepend to a scheme list

        // read vertices
        unsigned int num = m->mNumVertices;
        aiVector3D* src = m->mVertices;
        float* dest = new float[3 * num];
        for (j = 0; j < num; ++j) {
            dest[3*j]   = src[j].x;
            dest[3*j+1] = src[j].y;
            dest[3*j+2] = src[j].z;
        }
        DataBlock<3,float>* verts = new DataBlock<3,float>(num, dest);

        DataBlock<3,float>* norms = NULL;
        if (m->HasNormals()) {
            // read normals
            src = m->mNormals;
            dest = new float[3 * num];
            for (j = 0; j < num; ++j) {
                dest[j*3]   = src[j].x;
                dest[j*3+1] = src[j].y;
                dest[j*3+2] = src[j].z;
            }
            norms = new DataBlock<3,float>(num, dest);
        }

        IDataBlock* uvs = NULL;
        if (m->GetNumUVChannels() > 0) {
            unsigned int j = 0;
            // read texture coordinates
            unsigned int dim = m->mNumUVComponents[j];
            src = m->mTextureCoords[j];
            dest = new float[dim * num];
            for (unsigned int k = 0; k < num; ++k) {
                for (unsigned int l = 0; l < dim; ++l) {
                     dest[k*dim+l] = src[k][l];
                }
            }
            switch (dim) {
            case 2:
                uvs = new DataBlock<2,float>(num, dest);
                break;
            case 3:
                uvs = new DataBlock<3,float>(num, dest);
                break;
            default: 
                delete dest;
            };
        }

        // Float3DataBlockPtr col;
        // if (m->GetNumColorChannels() > 0) {
        //     aiColor4D* c = m->mColors[0];
        //     dest = new float[3 * num];
        //     for (j = 0; j < num; ++j) {
        //         dest[j*3]   = c[j].r;
        //         dest[j*3+1] = c[j].g;
        //         dest[j*3+2] = c[j].b;
        //     }
        //     col = Float3DataBlockPtr(new DataBlock<3,float>(num, dest));
        // }

        // assume that we only have triangles (see triangulate option).
        unsigned int* indexArr = new unsigned int[m->mNumFaces * 3];
        for (j = 0; j < m->mNumFaces; ++j) {
            aiFace src = m->mFaces[j];
            indexArr[j*3]   = src.mIndices[0];
            indexArr[j*3+1] = src.mIndices[1];
            indexArr[j*3+2] = src.mIndices[2];
        }
        Indices* indices = new Indices(m->mNumFaces*3, indexArr);

        add_db_scm(uvs);
        add_db_scm(norms);
        add_db_scm(verts);
        add_db_scm(indices);
        add_mesh_scm(m->mMaterialIndex);

        for (unsigned int k = 0; k < m->mNumBones; ++k) {
            aiBone* bone = m->mBones[k];
            bones.insert(bone->mName.data);
        } 
    }
}

void readNode(aiNode* node) {
    // printf("readnode name: %s\n", node->mName.data);

    // if node describes a bone then don't process it.
    if (bones.find(node->mName.data) != bones.end()) return;

    // construct a transformation node
    aiMatrix4x4 t = node->mTransformation;
    aiVector3D pos, scl;
    aiQuaternion rot;
    t.Decompose(scl, rot, pos);
    
    set_pos_scm(pos.x, pos.y, pos.z);
    set_rot_scm(rot.w, rot.x, rot.y, rot.z);
    set_scale_scm(scl.x, scl.y, scl.z);
    push_transformation_node_scm();

    // append meshes to the transformation node
    if ( node->mNumMeshes > 0 ) {
        // Create scene node and add all mesh nodes to it.
        for (unsigned int i = 0; i < node->mNumMeshes; ++i) {
            append_mesh_node_scm(node->mMeshes[i]);
        } 
    }
    
    // Go on and read nodes recursively.
    for (unsigned int i = 0; i < node->mNumChildren; ++i) {
        readNode(node->mChildren[i]);
    }
    pop_scene_parent_scm();
}

void readScene(const aiScene* scene) {
    aiNode* mRoot = scene->mRootNode;
    readNode(mRoot);
}

