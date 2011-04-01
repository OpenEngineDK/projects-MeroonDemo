INCLUDE(Setup.cmake)

FIND_PACKAGE(GLUT REQUIRED)

INCLUDE_DIRECTORIES(${GLUT_INCLUDE_DIR})

ADD_LIBRARY(CPPStuff assimp.cpp)

## extensions to base scheme/gambit
GAMBIT_ADD_LIBRARY(Scheme_Ext GAMBIT_MEROON
  vector.scm
)

GAMBIT_ADD_LIBRARY(Scheme_Stuff Scheme_Ext
  queue.scm
  datablock.scm
  keymap.scm
)

## project
GAMBIT_ADD_EXECUTABLE(MeroonDemo Scheme_Stuff
  quaternion.scm
  transformation.scm
  camera.scm
  texture.scm
  OpenGLShader.scm
  modules.scm
  canvas.scm
  geometry.scm
  scene.scm
  render.scm
  animation.scm
  assimp.scm
  opengl.scm
  glut.scm
  dotvisitor.scm
  boids.scm
  main.scm
)
TARGET_LINK_LIBRARIES(MeroonDemo
  OpenEngine_Core
  Extensions_OBJResource
  Extensions_TGAResource
  #Extensions_SDLImage
  Extensions_FreeImage
  Extensions_AssimpResource
  ${GLUT_LIBRARIES}
  CPPStuff
)
