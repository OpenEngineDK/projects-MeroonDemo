INCLUDE(Setup.cmake)

FIND_PACKAGE(GLUT REQUIRED)

INCLUDE_DIRECTORIES(${GLUT_INCLUDE_DIR})

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
  main.scm
)

# Project dependencies
TARGET_LINK_LIBRARIES(MeroonDemo
  # Core library dependencies
  OpenEngine_Core
  # Extensions
  Extensions_OpenGLRenderer
  Extensions_OBJResource
  Extensions_TGAResource
  ${GLUT_LIBRARIES}
)
