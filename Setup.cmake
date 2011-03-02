SET(GAMBITC ${GAMBIT_DEPS_BIN_DIR}/gsc)
LINK_DIRECTORIES(${GAMBIT_DEPS_LIB_DIR})
SET(GAMBIT_OUTPUT_LANGUAGE CXX)
SET(GAMBIT_LIBRARIES gambc m dl util)

# Setup the Meroon Object System
SET(GAMBIT_MEROON_SRC  ${MEROON_DEPS_LIB_DIR}/_meroon.c)
SET(GAMBIT_MEROON_LINK ${MEROON_DEPS_LIB_DIR}/_meroon_link)
SET_SOURCE_FILES_PROPERTIES(
  ${GAMBIT_MEROON_SRC} ${GAMBIT_MEROON_LINK}
  PROPERTIES LANGUAGE ${GAMBIT_OUTPUT_LANGUAGE} COMPILE_FLAGS "-w -D___LIBRARY")
ADD_LIBRARY(Meroon ${GAMBIT_MEROON_SRC} ${GAMBIT_MEROON_LINK})
TARGET_LINK_LIBRARIES(Meroon ${GAMBIT_LIBRARIES})

# (GAMBIT_ADD_EXECUTABLE target files ...) 
# Will define
# - target           : cmake target for the executable
# - target_C_FILES   : generated c files
# - target_LINK_FILE : generated link file
# - target_SCM_FILES : source scheme files (absolute path)
# - target_TMP_FILES : temporary output files (absolute path)
MACRO(GAMBIT_ADD_EXECUTABLE target)
  FOREACH(SRC ${ARGN})
    SET(SRC_SCM "${CMAKE_CURRENT_SOURCE_DIR}/${SRC}")
    STRING(REPLACE ".scm" ".c" SRC_TMP ${SRC_SCM})
    STRING(REPLACE ".scm" ".c" SRC_C   ${SRC})
    SET(${target}_SCM_FILES ${${target}_SCM_FILES} ${SRC_SCM})
    SET(${target}_TMP_FILES ${${target}_TMP_FILES} ${SRC_TMP})
    SET(${target}_C_FILES   ${${target}_C_FILES}   ${SRC_C})
  ENDFOREACH(SRC)
  SET(${target}_LINK_FILE ${target}_link.c)
  SET_SOURCE_FILES_PROPERTIES(
    ${${target}_C_FILES} ${${target}_LINK_FILE}
    PROPERTIES 
    GENERATED 1
    LANGUAGE ${GAMBIT_OUTPUT_LANGUAGE}
    COMPILE_FLAGS "-w"
    )
  ADD_CUSTOM_COMMAND(
    OUTPUT ${${target}_C_FILES} ${${target}_LINK_FILE}
    COMMAND ${GAMBITC} -link -l ${GAMBIT_MEROON_LINK} -o ${${target}_LINK_FILE} ${${target}_SCM_FILES}
    COMMAND mv ${${target}_TMP_FILES} .
    DEPENDS ${${target}_SCM_FILES} #${ARGN}
    COMMENT "Generating ${GAMBIT_OUTPUT_LANGUAGE} for target ${target}"
    )
  ADD_EXECUTABLE(${target} ${${target}_C_FILES} ${${target}_LINK_FILE})
  #TARGET_LINK_LIBRARIES(${target} gambc m dl util)
  TARGET_LINK_LIBRARIES(${target} Meroon)
ENDMACRO(GAMBIT_ADD_EXECUTABLE)
