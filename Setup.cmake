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
SET(GAMBITC_LOADED_LIBRARIES)

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
ADD_LIBRARY(GAMBIT_MEROON_SHARED SHARED emptyfile.c)
TARGET_LINK_LIBRARIES(${MEROON_DEPS_LIB_DIR}/_meroon.o1)

# This is an interal helper function for GAMBIT_ADD_LIBRARY/EXECUTABLE
# Generates:
# - target_C_FILES   : generated c files
# - target_LINK_FILE : generated link file (for static libraries)
# - target_LOAD_FILE : generated load file (for shared libraries)
# - target_SCM_FILES : source scheme files (absolute path)
# - target_TMP_FILES : temporary output files (absolute path)
# - target_EXTENDS   : list of extended targets
MACRO(GAMBIT_ADD_TARGET_HELPER type target extends)
  SET(${target}_SCM_FILES)
  SET(${target}_TMP_FILES)
  SET(${target}_C_FILES)
  SET(${target}_EXTENDS ${extends} ${${extends}_EXTENDS})
  FOREACH(SRC ${ARGN})
    SET(SRC_SCM "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}")
    STRING(REPLACE ".scm" ".c" SRC_TMP ${SRC_SCM})
    STRING(REPLACE ".scm" ".c" SRC_C   ${SRC})
    SET(${target}_SCM_FILES ${${target}_SCM_FILES} ${SRC_SCM})
    SET(${target}_TMP_FILES ${${target}_TMP_FILES} ${SRC_TMP})
    SET(${target}_C_FILES   ${${target}_C_FILES}   ${type}/${SRC_C})
  ENDFOREACH(SRC)
  SET(GAMBITC_PRELUDE)
  IF(NOT "${GAMBITC_LOADED_LIBRARIES}" STREQUAL "")
    FOREACH(LIB ${GAMBITC_LOADED_LIBRARIES})
      SET(GAMBITC_PRELUDE "(load \\\"${LIB}\\\") ${GAMBITC_PRELUDE}")
    ENDFOREACH(LIB)
    SET(GAMBITC_PRELUDE "-prelude" "\"${GAMBITC_PRELUDE}\"")
  ENDIF(NOT "${GAMBITC_LOADED_LIBRARIES}" STREQUAL "")
  IF(${type} STREQUAL "DYNAMIC")
  SET(${target}_LOAD_FILE ${type}/${target})
  SET(TMP ${${target}_LOAD_FILE}.o1.c)
  ADD_CUSTOM_COMMAND(
    OUTPUT ${${target}_C_FILES} ${${target}_LOAD_FILE}.o1.c 
    COMMAND mkdir -p ${type}/
    # COMMAND ${GAMBITC} ${GAMBITC_FLAGS}
    #         -link -flat -o ${${target}_LOAD_FILE}.o1.c
    # 	    ${${target}_SCM_FILES} #>/dev/null
    COMMAND ${GAMBITC} #${GAMBITC_FLAGS}
            -i ${CMAKE_CURRENT_SOURCE_DIR}/gsc-shared.scm
	    #${type}
	    ${${target}_LOAD_FILE}.o1.c
	    ${GAMBITC_LOADED_LIBRARIES}
    	    ${${target}_SCM_FILES} >/dev/null # ignore warnings from shared libs
    COMMAND mv ${${target}_TMP_FILES} ${type}/
    DEPENDS ${${target}_SCM_FILES} ${target} #DEPEND ON STATIC LIB (file race cond)
    COMMENT "Generating ${GAMBIT_OUTPUT_LANGUAGE} for target ${target}")
  ELSE(${type} STREQUAL "DYNAMIC")
  IF(${type} STREQUAL "LIBRARY")
    SET(DEPS ${extends}_SHARED)
  ENDIF(${type} STREQUAL "LIBRARY")    
  SET(${target}_LINK_FILE ${type}/${target}_link)
  SET(TMP ${${target}_LINK_FILE}.c)
  ADD_CUSTOM_COMMAND(
    OUTPUT ${${target}_C_FILES} ${${target}_LINK_FILE}.c 
    COMMAND mkdir -p ${type}/
    # COMMAND ${GAMBITC} ${GAMBITC_FLAGS} #${GAMBITC_PRELUDE}
    # 	    -link -l ${${extends}_LINK_FILE}
    #         -o ${${target}_LINK_FILE}.c 
    # 	    ${${target}_SCM_FILES}
    COMMAND ${GAMBITC} #${GAMBITC_FLAGS}
            -i ${CMAKE_CURRENT_SOURCE_DIR}/gsc-static.scm
	    ${${extends}_LINK_FILE}
            ${${target}_LINK_FILE}.c
	    ${GAMBITC_LOADED_LIBRARIES}
	    ${${target}_SCM_FILES}
    COMMAND mv ${${target}_TMP_FILES} ${type}/
    DEPENDS ${${target}_SCM_FILES} ${DEPS} #DEPEND ON EXTENDED SHARED LIB (load race cond)
    COMMENT "Generating ${GAMBIT_OUTPUT_LANGUAGE} for target ${target}")
  ENDIF(${type} STREQUAL "DYNAMIC")
  SET_SOURCE_FILES_PROPERTIES(
    ${${target}_C_FILES} ${TMP}
    PROPERTIES 
    GENERATED 1
    LANGUAGE ${GAMBIT_OUTPUT_LANGUAGE}
    COMPILE_FLAGS "-w -D___${type}"
    )
ENDMACRO(GAMBIT_ADD_TARGET_HELPER)

# (GAMBIT_ADD_LIBRARY target extends files ...)
MACRO(GAMBIT_ADD_LIBRARY target extends)
  ## make a shared library
  GAMBIT_ADD_TARGET_HELPER(DYNAMIC ${ARGV})
  ADD_LIBRARY(${target}_SHARED SHARED
    ${${target}_C_FILES}
    ${${target}_LOAD_FILE}.o1.c)
  SET_TARGET_PROPERTIES(${target}_SHARED PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_NAME ${target}
    SUFFIX ".o1")
  # TODO: should we link to other shared libraries?
  TARGET_LINK_LIBRARIES(${target}_SHARED ${extends}_SHARED)
  ## make a static library
  GAMBIT_ADD_TARGET_HELPER(LIBRARY ${ARGV})
  ADD_LIBRARY(${target} STATIC 
    ${${target}_C_FILES}
    ${${target}_LINK_FILE}.c)
  TARGET_LINK_LIBRARIES(${target} ${extends})
  #TARGET_LINK_LIBRARIES(${target} gambc m dl util)
ENDMACRO(GAMBIT_ADD_LIBRARY)

# (GAMBIT_ADD_EXECUTABLE target extends files ...) 
MACRO(GAMBIT_ADD_EXECUTABLE target extends)
  GAMBIT_ADD_TARGET_HELPER(PRIMAL ${ARGV})
  ADD_EXECUTABLE(${target} ${${target}_C_FILES} ${${target}_LINK_FILE}.c)
  #TARGET_LINK_LIBRARIES(${target} gambc m dl util)
  TARGET_LINK_LIBRARIES(${target} ${extends})
ENDMACRO(GAMBIT_ADD_EXECUTABLE)

MACRO(GAMBIT_LINK_LIBRARIES target)
  TARGET_LINK_LIBRARIES(${target} ${ARGN})
  TARGET_LINK_LIBRARIES(${target}_SHARED ${ARGN})
ENDMACRO(GAMBIT_LINK_LIBRARIES)

MACRO(GAMBIT_LOAD_LIBRARY target)
  SET(GAMBITC_LOADED_LIBRARIES ${GAMBITC_LOADED_LIBRARIES} ${target})
ENDMACRO(GAMBIT_LOAD_LIBRARY)
