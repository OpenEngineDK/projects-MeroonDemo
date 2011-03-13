(c-declare #<<C_DECLARE_END
#include <Scene/ISceneNode.h>
#include <Resources/ResourceManager.h>
#include <Resources/IModelResource.h>
#include <Resources/OBJResource.h>

using namespace OpenEngine::Scene;
using namespace OpenEngine::Resources;

ResourceManager<IModelResource>::AddPlugin(new OBJPlugin());

C_DECLARE_END
)

(c-define-type ISceneNode (pointer "ISceneNode"))

;; loads a model into a CompatNode using the existing OpenEngine
;; resource code
(define load-model
  (c-lambda (char-string) ISceneNode
#<<LOAD_MODEL_END
std::string path = DirectoryManager::FindFileInPath(___arg1);
IModelResourcePtr mod = ResourceManager<IModelResource>::Create(path);
mod->Load();
ISceneNode* node = mod->GetSceneNode();
mod->Unload();
___result_voidstar = node;
LOAD_MODEL_END
))

(define add-resource-path
  (c-lambda (char-string) void
    "DirectoryManager::AppendPath(___arg1);"))
