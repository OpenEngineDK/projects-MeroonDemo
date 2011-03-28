INCLUDE(Setup.cmake)

FIND_PACKAGE(GLUT REQUIRED)

INCLUDE_DIRECTORIES(${GLUT_INCLUDE_DIR})

ADD_LIBRARY(CPPStuff assimp.cpp)

## extensions to base scheme/gambit
GAMBIT_ADD_LIBRARY(Scheme_Ext GAMBIT_MEROON
  vector.scm
)

## project
GAMBIT_ADD_EXECUTABLE(MeroonDemo Scheme_Ext
  quaternion.scm
  queue.scm
  transformation.scm
  projection.scm
  datablock.scm
  texture.scm
  modules.scm
  objects.scm
  render.scm
  keymap.scm
  assimp.scm
  opengl.scm
  glut.scm
  dotvisitor.scm
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
