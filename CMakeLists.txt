INCLUDE(Setup.cmake)

GAMBIT_ADD_EXECUTABLE(MeroonDemo
  objects.scm
  main.scm
)

# Project dependencies
TARGET_LINK_LIBRARIES(MeroonDemo
  # Core library dependencies
  OpenEngine_Core
  # OpenEngine_Logging
  # OpenEngine_Display
  # OpenEngine_Devices
  # OpenEngine_Scene
  # Extensions
  Extensions_OpenGLRenderer
  Extensions_SDL
)
