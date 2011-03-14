(c-declare #<<C_DECLARE_END
#include <Scene/ISceneNode.h>
#include <Resources/ResourceManager.h>
#include <Resources/OBJResource.h>
#include <Resources/TGAResource.h>
#include <Renderers/TextureLoader.h>
#include <Renderers/OpenGL/Renderer.h>
#include <Renderers/OpenGL/RenderingView.h>
#include <Display/RenderCanvas.h>
#include <Display/OpenGL/TextureCopy.h>
#include <Utils/Timer.h>

using namespace OpenEngine::Scene;
using namespace OpenEngine::Resources;
using namespace OpenEngine::Renderers::OpenGL;
using namespace OpenEngine::Renderers;
using namespace OpenEngine::Display;
using namespace OpenEngine::Display::OpenGL;
using OpenEngine::Utils::Time;

Renderer*      render      = NULL;
RenderingView* render_view = NULL;
RenderCanvas*  canvas      = NULL;
TextureLoader* tloader     = NULL;
C_DECLARE_END
)

(c-define-type ISceneNode (pointer "ISceneNode"))

((c-lambda () void
#<<COMPAT_SETUP_END
ResourceManager<IModelResource>::AddPlugin(new OBJPlugin());
ResourceManager<ITextureResource>::AddPlugin(new TGAPlugin());

render      = new Renderer();
render_view = new RenderingView();
canvas      = new RenderCanvas(new TextureCopy());
tloader     = new TextureLoader(*render);
render->ProcessEvent().Attach(*render_view);
COMPAT_SETUP_END
))


;; PUBLIC COMPATIBILITY API

;; compatibility node
(define-class CompatNode Scene
  ([= scene :immutable]
   [= loaded :initializer (lambda () #f)]))

;; add a resource path
(define compat-add-resource-path
  (c-lambda (char-string) void
    "DirectoryManager::AppendPath(___arg1);"))

;; load a model into a compat scene node
(define (compat-load-model file)
  (instantiate CompatNode
    :scene (_compat-load-model file)))


;; INTERNAL FUNCTIONS

;; hook-in to the OpenGL rendering routine
(define-method (gl-render-scene ctx (node CompatNode))
  (with-access node (CompatNode scene loaded)
    (if (not loaded)
        (set! loaded (_compat-texture-load scene)))
    (_compat-render-scene scene)))

(define _compat-render-scene
  (c-lambda (ISceneNode) void
#<<COMPAT_RENDER_SCENE_END
Time time;
RenderingEventArg arg(*canvas, *render, time, 0);
render_view->Handle(arg);
COMPAT_RENDER_SCENE_END
))
    
(define _compat-texture-load
  (c-lambda (ISceneNode) bool
    "tloader->Load(*___arg1); ___result = true;"))

(define _compat-load-model
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