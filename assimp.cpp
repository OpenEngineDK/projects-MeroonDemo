#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags

#include <Resources/DataBlock.h>
#include <cstdio>

using namespace OpenEngine::Resources;

void add_db_scm(IDataBlock* db);
void add_false_db_scm();
void add_mesh_scm(int i);
void set_pos_scm(float x, float y, float z);
void set_rot_scm(float w, float x, float y, float z);
void set_scale_scm(float x, float y, float z);
void append_transformation_node_scm();
void append_mesh_node_scm(int i);

void append_material_scm(char* path);
void append_empty_material_scm();

void readMaterials(aiMaterial** ms, unsigned int size) {
    printf("c read materials\n");
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
    printf("c read meshes\n");
    unsigned int i, j;
    for (i = 0; i < size; ++i) {
        aiMesh* m = ms[size-i-1]; // iterate in reverse order since we append to a scheme list

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

        // Float3DataBlockPtr norm;
        // if (m->HasNormals()) {
        //     // read normals
        //     src = m->mNormals;
        //     dest = new float[3 * num];
        //     for (j = 0; j < num; ++j) {
        //         dest[j*3]   = src[j].x;
        //         dest[j*3+1] = src[j].y;
        //         dest[j*3+2] = src[j].z;
        //     }
        //     norm = Float3DataBlockPtr(new DataBlock<3,float>(num, dest));
        // }

        IDataBlock* uvs = NULL;
        //logger.info << "numUV: " << m->GetNumUVChannels() << logger.end;
        if (m->GetNumUVChannels() > 0) {
            unsigned int j = 0;
            // read texture coordinates
            unsigned int dim = m->mNumUVComponents[j];
            //logger.info << "numUVComponents: " << dim << logger.end;
            src = m->mTextureCoords[j];
            dest = new float[dim * num];
            for (unsigned int k = 0; k < num; ++k) {
                for (unsigned int l = 0; l < dim; ++l) {
                    // dest[k*dim]   = src[k].x;
                    // dest[k*dim+1] = src[k].y;
                    // dest[k*dim+2] = src[k].z;
                     dest[k*dim+l] = src[k][l];
                }
                    //logger.info << "texc: (" << src[k].x << ", " << src[k].y << ")" << logger.end; 
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
        add_db_scm(verts);
        add_db_scm(indices);
        add_mesh_scm(m->mMaterialIndex);
    }
}

void readNode(aiNode* node) {

//     unsigned int i;
//     ISceneNode* current = parent;
    aiMatrix4x4 t = node->mTransformation;

    // If the node holds any mesh we create a parent transformation node for the mesh.
    aiVector3D pos, scl;
    aiQuaternion rot;
    // NOTE: decompose seems buggy when it comes to rotations
    t.Decompose(scl, rot, pos);
    // Use rotation matrix to construct rotation quaternion instead.
    // aiMatrix3x3 m3 = rot.GetMatrix();

    
    set_pos_scm(pos.x, pos.y, pos.z);
    set_rot_scm(rot.w, rot.x, rot.y, rot.z);
    set_scale_scm(scl.x, scl.y, scl.z);
    append_transformation_node_scm();
            
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
}

void readScene(const aiScene* scene) {
    aiNode* mRoot = scene->mRootNode;
    readNode(mRoot);
}

