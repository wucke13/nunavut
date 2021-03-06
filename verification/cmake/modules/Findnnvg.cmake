#
# Find nnvg and setup python environment to generate C++ from DSDL.
# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#

# +---------------------------------------------------------------------------+
# | BUILD FUNCTIONS
# +---------------------------------------------------------------------------+
#
# :function: create_dsdl_target
# Creates a target that will generate source code from dsdl definitions.
#
# :param str ARG_TARGET_NAME:               The name to give the target.
# :param str ARG_OUTPUT_LANGUAGE            The language to generate for this target.
# :param Path ARG_OUTPUT_FOLDER:            The directory to generate all source under.
# :param Path ARG_DSDL_ROOT_DIR:            A directory containing the root namespace dsdl.
# :param bool ARG_ENABLE_CLANG_FORMAT:      If ON then clang-format will be run on each generated file.
# :param ...:                               A list of paths to use when looking up dependent DSDL types.
# :returns: Sets a variable "ARG_TARGET_NAME"-OUTPUT in the parent scope to the list of files the target
#           will generate. For example, if ARG_TARGET_NAME == 'foo-bar' then after calling this function
#           ${foo-bar-OUTPUT} will be set to the list of output files.
#
function (create_dsdl_target ARG_TARGET_NAME ARG_OUTPUT_LANGUAGE ARG_OUTPUT_FOLDER ARG_DSDL_ROOT_DIR ARG_ENABLE_CLANG_FORMAT)

    set(LOOKUP_DIR_CMD_ARGS "")

    if (${ARGC} GREATER 5)
        foreach(ARG_N RANGE 5 ${ARGC}-1)
            list(APPEND LOOKUP_DIR_CMD_ARGS " -I ${ARGV${ARG_N}}")
        endforeach(ARG_N)
    endif()

    execute_process(COMMAND ${NNVG}
                                --list-outputs
                                --target-language ${ARG_OUTPUT_LANGUAGE}
                                -O ${ARG_OUTPUT_FOLDER}
                                ${LOOKUP_DIR_CMD_ARGS}
                                ${ARG_DSDL_ROOT_DIR}
                    OUTPUT_VARIABLE OUTPUT_FILES
                    RESULT_VARIABLE LIST_OUTPUTS_RESULT)

    if(NOT LIST_OUTPUTS_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to retrieve a list of headers nnvg would "
                            "generate for the ${ARG_TARGET_NAME} target (${LIST_OUTPUTS_RESULT})"
                            " (${NNVG})")
    endif()

    execute_process(COMMAND ${NNVG}
                                --list-inputs
                                --target-language ${ARG_OUTPUT_LANGUAGE}
                                -O ${ARG_OUTPUT_FOLDER}
                                ${LOOKUP_DIR_CMD_ARGS}
                                ${ARG_DSDL_ROOT_DIR}
                    OUTPUT_VARIABLE INPUT_FILES
                    RESULT_VARIABLE LIST_INPUTS_RESULT)

    if(NOT LIST_INPUTS_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to resolve inputs using nnvg for the ${ARG_TARGET_NAME} "
                            "target (${LIST_INPUTS_RESULT})"
                            " (${NNVG})")
    endif()

    if(ARG_ENABLE_CLANG_FORMAT AND CLANG_FORMAT)
        set(CLANG_FORMAT_ARGS -pp-rp=${CLANG_FORMAT} -pp-rpa=-i -pp-rpa=-style=file)
    else()
        set(CLANG_FORMAT_ARGS "")
    endif()

    add_custom_command(OUTPUT ${OUTPUT_FILES}
                       COMMAND ${NNVG}
                                    --target-language ${ARG_OUTPUT_LANGUAGE}
                                    -O ${ARG_OUTPUT_FOLDER}
                                    ${LOOKUP_DIR_CMD_ARGS}
                                    ${CLANG_FORMAT_ARGS}
                                    ${ARG_DSDL_ROOT_DIR}
                       DEPENDS ${INPUT_FILES}
                       WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                       COMMENT "Running nnvg")

    add_custom_target(${ARG_TARGET_NAME}-gen
                      DEPENDS ${OUTPUT_FILES})

    add_library(${ARG_TARGET_NAME} INTERFACE)

    add_dependencies(${ARG_TARGET_NAME} ${ARG_TARGET_NAME}-gen)

    target_include_directories(${ARG_TARGET_NAME} INTERFACE ${ARG_OUTPUT_FOLDER})

    set(${ARG_TARGET_NAME}-OUTPUT ${OUTPUT_FILES} PARENT_SCOPE)

endfunction(create_dsdl_target)


# +---------------------------------------------------------------------------+
# | CONFIGURE: PYTHON ENVIRONMENT
# +---------------------------------------------------------------------------+

if(NOT TOX)

    message(STATUS "tox was not found. You must have nunavut and its"
                   " dependencies available in the global python environment.")

    find_program(NNVG nnvg)

else()

    find_program(NNVG nnvg HINTS ${TOX_LOCAL_PYTHON_BIN})

    if (NOT NNVG)
        message(WARNING "nnvg program was not found. The build will probably fail. (${NNVG})")
    endif()
endif()

# +---------------------------------------------------------------------------+
# | CONFIGURE: VALIDATE NNVG
# +---------------------------------------------------------------------------+
if (NNVG)
    execute_process(COMMAND ${NNVG} --version
                    OUTPUT_VARIABLE NNVG_VERSION
                    RESULT_VARIABLE NNVG_VERSION_RESULT)

    if(NNVG_VERSION_RESULT EQUAL 0)
        string(STRIP ${NNVG_VERSION} NNVG_VERSION)
        message(STATUS "${NNVG} --version: ${NNVG_VERSION}")
    endif()
endif()

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(nnvg
    REQUIRED_VARS NNVG_VERSION
)

