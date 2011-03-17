INCLUDE(Setup.cmake)

FIND_PACKAGE(GLUT REQUIRED)

INCLUDE_DIRECTORIES(${GLUT_INCLUDE_DIR})

ADD_LIBRARY(CPPStuff
  assimp.cpp
)
 
GAMBIT_ADD_EXECUTABLE(MeroonDemo
  vector.scm
  quaternion.scm
  transformation.scm
  datablock.scm
  objects.scm
  render.scm
  opengl.scm
  glut.scm
  compat.scm
  assimp.scm
  main.scm
)

# Project dependencies
TARGET_LINK_LIBRARIES(MeroonDemo
  CPPStuff
  # Core library dependencies
  OpenEngine_Core
  # Extensions
  Extensions_OpenGLRenderer
  Extensions_AssimpResource ## just a hack to get the assimp source which is included in the extension
  Extensions_OBJResource
  Extensions_TGAResource
  ${GLUT_LIBRARIES}
)
