# Some gambit variables...
SET(GAMBITC ${GAMBIT_DEPS_BIN_DIR}/gsc)
LINK_DIRECTORIES(${GAMBIT_DEPS_LIB_DIR})
INCLUDE_DIRECTORIES(${GAMBIT_DEPS_INCLUDE_DIR})
SET(GAMBIT_OUTPUT_LANGUAGE CXX)
SET(GAMBIT_LIBRARIES gambc m dl util)
SET(GAMBITC_FLAGS "")
IF(CMAKE_BUILD_TYPE STREQUAL debug)
  SET(GAMBITC_FLAGS ${GAMBITC_FLAGS} -debug -track-scheme)
ENDIF(CMAKE_BUILD_TYPE STREQUAL debug)

# Create a Meroon library that extends plain gambit
# Target: GAMBIT_MEROON
SET(GAMBIT_MEROON_SRC  ${MEROON_DEPS_LIB_DIR}/_meroon.c)
SET(GAMBIT_MEROON_LINK_FILE ${MEROON_DEPS_LIB_DIR}/_meroon_link)
SET_SOURCE_FILES_PROPERTIES(
  ${GAMBIT_MEROON_SRC} ${GAMBIT_MEROON_LINK_FILE}
  PROPERTIES
  LANGUAGE ${GAMBIT_OUTPUT_LANGUAGE}
  COMPILE_FLAGS "-w -D___LIBRARY")
ADD_LIBRARY(GAMBIT_MEROON ${GAMBIT_MEROON_SRC} ${GAMBIT_MEROON_LINK_FILE})
TARGET_LINK_LIBRARIES(GAMBIT_MEROON ${GAMBIT_LIBRARIES})

# This is an interal helper function for GAMBIT_ADD_LIBRARY/EXECUTABLE
# Generates:
# - target_C_FILES   : generated c files
# - target_LINK_FILE : generated link file
# - target_SCM_FILES : source scheme files (absolute path)
# - target_TMP_FILES : temporary output files (absolute path)
MACRO(GAMBIT_ADD_TARGET_HELPER type target extends)
  FOREACH(SRC ${ARGN})
    SET(SRC_SCM "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}")
    STRING(REPLACE ".scm" ".c" SRC_TMP ${SRC_SCM})
    STRING(REPLACE ".scm" ".c" SRC_C   ${SRC})
    SET(${target}_SCM_FILES ${${target}_SCM_FILES} ${SRC_SCM})
    SET(${target}_TMP_FILES ${${target}_TMP_FILES} ${SRC_TMP})
    SET(${target}_C_FILES   ${${target}_C_FILES}   ${SRC_C})
  ENDFOREACH(SRC)
  SET(${target}_LINK_FILE ${target}_link)
  SET_SOURCE_FILES_PROPERTIES(
    ${${target}_C_FILES} ${${target}_LINK_FILE}.c
    PROPERTIES 
    GENERATED 1
    LANGUAGE ${GAMBIT_OUTPUT_LANGUAGE}
    COMPILE_FLAGS "-w -D___${type}"
    )
  ADD_CUSTOM_COMMAND(
    OUTPUT ${${target}_C_FILES} ${${target}_LINK_FILE}.c
    COMMAND echo ${GAMBITC} ${GAMBITC_FLAGS} -link -l ${${extends}_LINK_FILE} -o ${${target}_LINK_FILE}.c ${${target}_SCM_FILES}
    COMMAND ${GAMBITC} ${GAMBITC_FLAGS} -link -l ${${extends}_LINK_FILE} -o ${${target}_LINK_FILE}.c ${${target}_SCM_FILES}
    COMMAND mv ${${target}_TMP_FILES} .
    DEPENDS ${${target}_SCM_FILES} #${ARGN}
    COMMENT "Generating ${GAMBIT_OUTPUT_LANGUAGE} for target ${target}"
    )
ENDMACRO(GAMBIT_ADD_TARGET_HELPER)

# (GAMBIT_ADD_LIBRARY target extends files ...)
MACRO(GAMBIT_ADD_LIBRARY target extends)
  GAMBIT_ADD_TARGET_HELPER(LIBRARY ${ARGV})
  ADD_LIBRARY(${target} ${${target}_C_FILES} ${${target}_LINK_FILE}.c)
  #TARGET_LINK_LIBRARIES(${target} gambc m dl util)
  TARGET_LINK_LIBRARIES(${target} ${extends})
ENDMACRO(GAMBIT_ADD_LIBRARY)

# (GAMBIT_ADD_EXECUTABLE target extends files ...) 
MACRO(GAMBIT_ADD_EXECUTABLE target extends)
  GAMBIT_ADD_TARGET_HELPER(PRIMAL ${ARGV})
  ADD_EXECUTABLE(${target} ${${target}_C_FILES} ${${target}_LINK_FILE}.c)
  #TARGET_LINK_LIBRARIES(${target} gambc m dl util)
  TARGET_LINK_LIBRARIES(${target} ${extends})
ENDMACRO(GAMBIT_ADD_EXECUTABLE)
