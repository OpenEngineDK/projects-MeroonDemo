#define ___VERSION 406000
#include <gambit.h>
#include <assimp.hpp>      // C++ importer interface
#include <aiScene.h>       // Output data structure
#include <aiPostProcess.h> // Post processing flags

// #include <Resources/DataBlock.h>
#include <cstdio>

#include <map>
#include <vector>
#include <string>

// using namespace OpenEngine::Resources;
using namespace std;


// Q: what is the difference between bone and transformation??  
// A: bones are transformations which contain vertex weights and are
//    used to skin an animated mesh.

map<string, unsigned int> bones, lights;    // bones referenced by animations
map<string, unsigned int> transformations;  // transformations referenced by animations

void add_vertex_attribute_scm(char* type, int elm_size, int elm_count, void* data);
void add_false_db_scm();
void add_mesh_scm(int i);
void set_pos_scm(float x, float y, float z);
void set_rot_scm(float w, float x, float y, float z);
void set_scale_scm(float x, float y, float z);
int push_transformation_node_scm();
void push_bone_node_scm(int i);
void pop_scene_parent_scm();
void append_mesh_node_scm(int i);

int add_bone_node_scm(vector<pair<unsigned int, float> >* weights);//, float* offset);

void append_material_scm(char* path);
void append_empty_material_scm();


// animation functions
void make_position_key_vector_scm(int size);
void make_rotation_key_vector_scm(int size);
void make_scaling_key_vector_scm(int size);

void add_position_key_scm(float time, float x, float y, float z, int i);
void add_rotation_key_scm(float time, float w, float x, float y, float z, int i);
void add_scaling_key_scm(float time, float x, float y, float z, int i);

void add_bone_animation_scm(int bone_index);
void add_transformation_animation_scm(int trans_index);

void add_animation_scm(char* name, float duration, float ticks_per_second);
void clear_animation_keys_scm();

void add_animated_mesh_scm(int material_index, int number_of_bones);


void add_directional_light_scm(___SCMOBJ amb, ___SCMOBJ diff, ___SCMOBJ spec, ___SCMOBJ dir);
void add_point_light_scm(___SCMOBJ amb, ___SCMOBJ diff, ___SCMOBJ spec, ___SCMOBJ pos,
                         float att_const, float att_lin, float att_quad);
void push_light_node_scm(int light_index);

void readLights(aiLight** ls, unsigned int size) {
    lights.clear();
    unsigned int i;
    for (i = 0; i < size; ++i) {
        aiLight* l = ls[i];
        
        aiColor3D ai_amb = l->mColorAmbient;
        aiColor3D ai_diff = l->mColorDiffuse;
        aiColor3D ai_spec = l->mColorSpecular;
        ___F32* col;
        
        ___SCMOBJ amb = ___EXT(___alloc_scmobj) (___sF32VECTOR, 4*sizeof(___F32), ___STILL);
        col = ___CAST(___F32*,___BODY(amb));
        col[0] = ai_amb.r;
        col[1] = ai_amb.g;
        col[2] = ai_amb.b;
        col[3] = 1.0;

        ___SCMOBJ diff = ___EXT(___alloc_scmobj) (___sF32VECTOR, 4*sizeof(___F32), ___STILL);
        col = ___CAST(___F32*,___BODY(diff));
        col[0] = ai_diff.r;
        col[1] = ai_diff.g;
        col[2] = ai_diff.b;
        col[3] = 1.0;

        ___SCMOBJ spec = ___EXT(___alloc_scmobj) (___sF32VECTOR, 4*sizeof(___F32), ___STILL);
        col = ___CAST(___F32*,___BODY(spec));
        col[0] = ai_spec.r;
        col[1] = ai_spec.g;
        col[2] = ai_spec.b;
        col[3] = 1.0;

        switch(l->mType) {
        case aiLightSource_DIRECTIONAL: {
            aiVector3D ai_dir = l->mDirection;
            ___SCMOBJ dir = ___EXT(___alloc_scmobj) (___sF32VECTOR, 3*sizeof(___F32), ___STILL);
            float* pdir = ___CAST(___F32*,___BODY(dir));
            pdir[0] = ai_dir.x;
            pdir[1] = ai_dir.y;
            pdir[2] = ai_dir.z;
            add_directional_light_scm(amb, diff, spec, dir);
            lights[l->mName.data] = i+1;
            ___EXT(___release_scmobj) (dir);
            break;
        }
        case aiLightSource_POINT: {
            aiVector3D ai_pos = l->mPosition;
            ___SCMOBJ pos = ___EXT(___alloc_scmobj) (___sF32VECTOR, 3*sizeof(___F32), ___STILL);
            float* ppos = ___CAST(___F32*,___BODY(pos));
            ppos[0] = ai_pos.x;
            ppos[1] = ai_pos.y;
            ppos[2] = ai_pos.z;
            add_point_light_scm(amb, diff, spec, pos, 
                                l->mAttenuationConstant, 
                                l->mAttenuationLinear, 
                                l->mAttenuationQuadratic);
            ___EXT(___release_scmobj) (pos);
            break;
        }
        // case aiLightSource_SPOT:
        //     add_spot_light_scm();
        //     break;
        default:
            break;
        }
        ___EXT(___release_scmobj) (amb);
        ___EXT(___release_scmobj) (diff);
        ___EXT(___release_scmobj) (spec);
    }
}

void readAnimations(aiAnimation** anims, unsigned int size) {
    unsigned int i, j, k;
    // printf("num animations: %d\n", size);
    for (i = 0; i < size; ++i) {
        aiAnimation* anim = anims[size-i-1];
        // printf("num bone anims: %d\n", anim->mNumChannels);

        for (j = 0; j < anim->mNumChannels; ++j) {
            aiNodeAnim* bone_anim = anim->mChannels[anim->mNumChannels-j-1];
            
            make_position_key_vector_scm(bone_anim->mNumPositionKeys);
            for (k = 0; k < bone_anim->mNumPositionKeys; ++k) {
                aiVectorKey key = bone_anim->mPositionKeys[bone_anim->mNumPositionKeys-k-1];
                double time = key.mTime;
                aiVector3D pos = key.mValue;
                
                // printf("id: %d pos-key: %f value: (%f, %f, %f)\n", k, time, pos.x, pos.y, pos.z);
                add_position_key_scm(time, pos.x, pos.y, pos.z, bone_anim->mNumPositionKeys-k-1);
            }

            make_rotation_key_vector_scm(bone_anim->mNumRotationKeys);
            for (k = 0; k < bone_anim->mNumRotationKeys; ++k) {
                aiQuatKey key = bone_anim->mRotationKeys[bone_anim->mNumRotationKeys-k-1];
                double time = key.mTime;
                aiQuaternion q = key.mValue;
                // printf("id: %d rot-key: %f value: (%f, %f, %f, %f)\n", k, time, q.w, q.x, q.y, q.z);
                add_rotation_key_scm(time, q.w, q.x, q.y, q.z, bone_anim->mNumRotationKeys-k-1);
            }

            make_scaling_key_vector_scm(bone_anim->mNumScalingKeys);
            for (k = 0; k < bone_anim->mNumScalingKeys; ++k) {
                aiVectorKey key = bone_anim->mScalingKeys[bone_anim->mNumScalingKeys-k-1];
                double time = key.mTime;
                aiVector3D scale = key.mValue;
                // printf("id: %d scale-key: %f value: (%f, %f, %f)\n", k, time, scale.x, scale.y, scale.z);
                add_scaling_key_scm(time, scale.x, scale.y, scale.z, bone_anim->mNumScalingKeys-k-1);
            }
            
            // get the referenced bone
            map<string, unsigned int>::iterator itr = bones.find(bone_anim->mNodeName.data);
            if (itr != bones.end()) {
                // printf("added bone anim: %s \n", bone_anim->mNodeName.data);
                // node is a transformation 
                add_bone_animation_scm((*itr).second);
            }
            else {
                // or get the referenced tranformation node
                map<string, unsigned int>::iterator itr = transformations.find(bone_anim->mNodeName.data);
                if (itr != transformations.end()) {
                    // printf("added transformation anim: %s \n", bone_anim->mNodeName.data);
                    // node is a transformation 
                    add_transformation_animation_scm((*itr).second);
                }
                else {
                    // printf("animation node not found: %s\n", bone_anim->mNodeName.data);
                    clear_animation_keys_scm();
                }
            }
        }
        add_animation_scm(anim->mName.data, anim->mDuration, anim->mTicksPerSecond);

        // for (j = 0; j < anim->mNumMeshChannels; ++j) {
        //     aiMeshAnim* mesh_anim = anim->mMeshChannels[anim->mNumMeshChannels-j-1];
        //     for (k = 0; k < mesh_anim->mNumKeys; ++k) {
        //         aiMeshKey key = mesh_anim->mKeys[mesh_anim->mNumKeys-k-1];
        //         double time = key.mTime;
        //         unsigned int mesh_index = key.mValue;
        //         add_mesh_key_scm(time, mesh_index);
        //     }
        //     add_mesh_animation_scm();
        // }
    }
}

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
        
        if (m->HasBones()) {
            for (j = 0; j < m->mNumBones; ++j) {
                aiBone* bone = m->mBones[j];
                vector<pair<unsigned int, float> >* weights
                    = new vector<pair<unsigned int, float> > (bone->mNumWeights);
                aiVertexWeight* ws = bone->mWeights;
                for (unsigned int k = 0; k < bone->mNumWeights; ++k) {
                    (*weights)[k] = make_pair(ws[k].mVertexId, ws[k].mWeight);
                }
                
                // construct a transformation node
                aiMatrix4x4 t = bone->mOffsetMatrix;
                aiVector3D pos, scl;
                aiQuaternion rot;
                t.Decompose(scl, rot, pos);
                
                set_pos_scm(pos.x, pos.y, pos.z);
                set_rot_scm(rot.w, rot.x, rot.y, rot.z);
                set_scale_scm(scl.x, scl.y, scl.z);

                unsigned int bone_index = add_bone_node_scm(weights);//, offset);
                //printf("added bone: %s with index: %d\n", bone->mName.data, bone_index); 
                bones[bone->mName.data] = bone_index;
            }
        }

        // read vertices
        unsigned int count = m->mNumVertices;
        aiVector3D* src = m->mVertices;
        float* verts = new float[3 * count];
        for (j = 0; j < count; ++j) {
            verts[3*j]   = src[j].x;
            verts[3*j+1] = src[j].y;
            verts[3*j+2] = src[j].z;
        }
        // DataBlock<3,float>* verts = new DataBlock<3,float>(count, dest);

        // DataBlock<3,float>* norms = NULL;
        float* norms = NULL;

        if (m->HasNormals()) {
            // read normals
            src = m->mNormals;
            norms = new float[3 * count];
            for (j = 0; j < count; ++j) {
                norms[j*3]   = src[j].x;
                norms[j*3+1] = src[j].y;
                norms[j*3+2] = src[j].z;
            }
            // norms = new DataBlock<3,float>(count, dest);
        }

        // IDataBlock* uvs = NULL;
        float* uvs = NULL;
        unsigned int dim = 0;
        if (m->GetNumUVChannels() > 0) {
            unsigned int j = 0;
            // read texture coordinates
            dim = m->mNumUVComponents[j];
            src = m->mTextureCoords[j];
            uvs = new float[dim * count];
            for (unsigned int k = 0; k < count; ++k) {
                for (unsigned int l = 0; l < dim; ++l) {
                     uvs[k*dim+l] = src[k][l];
                }
            }
            // switch (dim) {
            // case 2:
            //     uvs = new DataBlock<2,float>(count, dest);
            //     break;
            // case 3:
            //     uvs = new DataBlock<3,float>(count, dest);
            //     break;
            // default: 
            //     delete dest;
            // };
        }

        // Float3DataBlockPtr col;
        // if (m->GetNumColorChannels() > 0) {
        //     aiColor4D* c = m->mColors[0];
        //     dest = new float[3 * count];
        //     for (j = 0; j < count; ++j) {
        //         dest[j*3]   = c[j].r;
        //         dest[j*3+1] = c[j].g;
        //         dest[j*3+2] = c[j].b;
        //     }
        //     col = Float3DataBlockPtr(new DataBlock<3,float>(count, dest));
        // }

        // assume that we only have triangles (see triangulate option).
        unsigned int index_count = m->mNumFaces * 3;
        void* indices;
        char index_type[10]; 
        if (count <= 0xFFFF) {
            unsigned short* indices16 = new unsigned short[index_count];
            for (j = 0; j < m->mNumFaces; ++j) {
                aiFace src = m->mFaces[j];
                indices16[j*3]   = src.mIndices[0];
                indices16[j*3+1] = src.mIndices[1];
                indices16[j*3+2] = src.mIndices[2];
            }
            indices = indices16;
            strcpy(index_type, "uint16");
        }
        else {
            unsigned int* indices32 = new unsigned int[index_count];
            for (j = 0; j < m->mNumFaces; ++j) {
                aiFace src = m->mFaces[j];
                indices32[j*3]   = src.mIndices[0];
                indices32[j*3+1] = src.mIndices[1];
                indices32[j*3+2] = src.mIndices[2];
            }
            indices = indices32;
            strcpy(index_type, "uint32");
            // index_type = "uint32";
        }
        // Indices* indices = new Indices(m->mNumFaces*3, indexArr);

        char f32_type[10];
        strcpy(f32_type, "float32");

        if (m->HasBones()) {
            // add a copy of vertices and normals for original bind pose use.
            // @todo if more attributes need to be animated, they should also be copied.
            float* verts_copy = new float[3 * count];
            memcpy(verts_copy, verts, sizeof(float) * 3 * count);
            // DataBlock<3,float>* verts_copy = new DataBlock<3,float>(count, dest);

            float* norms_copy = new float[3 * count];
            memcpy(norms_copy, norms, sizeof(float) * 3 * count);
            // DataBlock<3,float>* norms_copy = new DataBlock<3,float>(count, dest);
        
            // add_db_scm(norms_copy);
            // add_db_scm(verts_copy);
            
            // add_db_scm(uvs);
            // add_db_scm(norms);
            // add_db_scm(verts);
            // add_db_scm(indices);

            add_vertex_attribute_scm(f32_type, 3, count, norms_copy);
            add_vertex_attribute_scm(f32_type, 3, count, verts_copy);
            
            add_vertex_attribute_scm(f32_type, dim, count, uvs);
            add_vertex_attribute_scm(f32_type, 3, count, norms);
            add_vertex_attribute_scm(f32_type, 3, count, verts);

            add_vertex_attribute_scm(index_type, 1, index_count, indices);
            add_animated_mesh_scm(m->mMaterialIndex, m->mNumBones);
        }
        else {
            add_vertex_attribute_scm(f32_type, dim, count, uvs);
            add_vertex_attribute_scm(f32_type, 3, count, norms);
            add_vertex_attribute_scm(f32_type, 3, count, verts);

            add_vertex_attribute_scm(index_type, 1, index_count, indices);
            // add_vertex_attribute_scm(uvs);
            // add_vertex_attribute_scm(norms);
            // add_vertex_attribute_scm(verts);
            // add_vertex_attribute_scm(indices);
            add_mesh_scm(m->mMaterialIndex);
        }
    }
}

void readNode(const aiNode* node) {
    // printf("readnode name: %s\n", node->mName.data);

    // construct a transformation node
    aiMatrix4x4 t = node->mTransformation;
    aiVector3D pos, scl;
    aiQuaternion rot;
    t.Decompose(scl, rot, pos);
    
    set_pos_scm(pos.x, pos.y, pos.z);
    set_rot_scm(rot.w, rot.x, rot.y, rot.z);
    set_scale_scm(scl.x, scl.y, scl.z);

    // printf("node name: %s\n", node->mName.data);
    map<string, unsigned int>::iterator itr = bones.find(node->mName.data);
    if (itr == bones.end()) {
        // node is a transformation 
        // printf("no bone found\n");
        unsigned int trans_index = push_transformation_node_scm();
        transformations[node->mName.data] = trans_index;
    }
    else {
        // node is a bone
        // printf("bone found\n");
        push_bone_node_scm((*itr).second);
    }

    itr = lights.find(node->mName.data);
    if (itr != lights.end()) {
        printf("add light node: %s\n", node->mName.data);
        push_light_node_scm((*itr).second);
    }

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
