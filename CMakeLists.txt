INCLUDE(Setup.cmake)

FIND_PACKAGE(GLUT REQUIRED)

INCLUDE_DIRECTORIES(${GLUT_INCLUDE_DIR})

ADD_LIBRARY(CPPStuff assimp.cpp)

## extensions to base scheme/gambit
GAMBIT_ADD_LIBRARY(OE_Data GAMBIT_MEROON
  vector.scm
)
GAMBIT_LOAD_LIBRARY(OE_Data)

## Standard OE objects defined by Meroon. These are made available to
## later modules by loading them into the compiler
GAMBIT_ADD_LIBRARY(OE_Objects OE_Data
  # quaternion should be redefined as a f42 vec and moved to OE_Data
  # utility types
  quaternion.scm 
  transformation.scm
  geometry.scm
  # canvas
  canvas.scm
  # scene
  scene.scm
  # rendering
  texture.scm
  animation.scm # maybe move this
  camera.scm
  render.scm
)
GAMBIT_LINK_LIBRARIES(OE_Objects
  OpenEngine_Logging
  OpenEngine_Resources
  Extensions_FreeImage
)
GAMBIT_LOAD_LIBRARY(OE_Objects)

## misc data types, subject to change
GAMBIT_ADD_LIBRARY(OE_Misc OE_Objects
  queue.scm
  datablock.scm
  keymap.scm
)
## datablock depends on oe math
GAMBIT_LINK_LIBRARIES(OE_Misc
  OpenEngine_Core
  OpenEngine_Math
)

## rendering environment
GAMBIT_ADD_LIBRARY(OE_OpenGL_Env OE_Misc
  opengl.scm
  glut.scm
  #qt.scm
)
GAMBIT_LINK_LIBRARIES(OE_OpenGL_Env
  ${GLUT_LIBRARIES}
)

## project
GAMBIT_ADD_EXECUTABLE(MeroonDemo OE_OpenGL_Env
  OpenGLShader.scm
  modules.scm
  assimp.scm
  dotvisitor.scm
  boids.scm
  main.scm
)
TARGET_LINK_LIBRARIES(MeroonDemo
  OpenEngine_Core
  Extensions_OBJResource
  Extensions_TGAResource
  Extensions_AssimpResource
  CPPStuff
)
