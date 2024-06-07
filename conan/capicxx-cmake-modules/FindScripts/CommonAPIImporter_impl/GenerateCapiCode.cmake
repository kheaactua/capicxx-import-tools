## Prints a list as an itemized list
function(LIST_MESSAGE)
  set(options)
  set(oneValueArgs HEADER LEVEL)
  set(multiValueArgs ITEMS)
  cmake_parse_arguments(LM "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  message(${LM_LEVEL} ${LM_HEADER})
  list(APPEND CMAKE_MESSAGE_INDENT " - ")
  foreach(i IN LISTS LM_ITEMS)
    message(${LM_LEVEL} ${i})
  endforeach()
  list(POP_BACK CMAKE_MESSAGE_INDENT)
endfunction()

## Separated a package string into a package and interface name.
## e.g. com.sync.api.helloworld will set the variables
## <OUTPUT_PREFIX>_PACKAGE_PATH = com/sync/api
## <OUTPUT_PREFIX>_INTERFACE    = helloworld
function(SEP_PACKAGE)
  set(options)
  set(oneValueArgs FULL_PACKAGE OUTPUT_PREFIX)
  set(multiValueArgs)
  cmake_parse_arguments(SP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(SP_OUTPUT_PREFIX)
    set(OUTPUT_PREFIX "${SP_OUTPUT_PREFIX}_")
  else()
    set(OUTPUT_PREFIX "")
  endif()

  string(REGEX MATCH "\\." m ${SP_FULL_PACKAGE})
  if(m)
    string(REGEX REPLACE "^([a-zA-Z0-9_\.\-]+)\\.([a-zA-Z0-9_\-]+)$" "\\1;\\2" sep_list ${SP_FULL_PACKAGE})
    list(GET sep_list 0 package)
    string(REGEX REPLACE "\\." "/" package ${package})
    set(${OUTPUT_PREFIX}PACKAGE_PATH ${package} PARENT_SCOPE)
    list(GET sep_list 1 interface)
    set(${OUTPUT_PREFIX}INTERFACE ${interface} PARENT_SCOPE)
  else()
    message(WARNING "FULL_PACKAGE (\"${SP_FULL_PACKAGE}\") should include the fully resolved path, e.g. com.sync.myPackage")

    set(${OUTPUT_PREFIX}PACKAGE_PATH "" PARENT_SCOPE)
    set(${OUTPUT_PREFIX}INTERFACE ${SP_FULL_PACKAGE} PARENT_SCOPE)
  endif()
endfunction()


## Parse a path with expandable macros to return actual paths either the core
## or transport lists
macro(PROCESS_USER_PATHS)
  set(options)
  set(oneValueArgs CORE_FILES_LIST TRANSPORT_FILES_LIST INTERFACE)
  set(multiValueArgs USER_PATHS)
  cmake_parse_arguments(PUP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  foreach(f IN LISTS PUP_USER_PATHS)
    string(REGEX MATCH "^%${PUP_INTERFACE}_" match_interface ${f})
    if("${match_interface}" STREQUAL "")
      message(DEBUG "PUP: Ignoring ${f}")
      continue()
    else()

      # CMake doesn't support look-aheads/behinds, so doing this the long way
      string(REGEX REPLACE "%([a-zA-Z0-9_-]+)%.*$" "\\1" var_name ${f})
      string(REGEX REPLACE "%([a-zA-Z0-9_-]+)%" "${${var_name}}" expanded_file ${f})

      string(REGEX MATCH "_(TRANSPORT|CORE)_" match_gen ${f})
      if("${match_gen}" STREQUAL "_TRANSPORT_")
        message(DEBUG "Appending ${expanded_file} to ${PUP_TRANSPORT_FILES_LIST}")
        LIST(APPEND ${PUP_TRANSPORT_FILES_LIST} ${expanded_file})
      else()
        message(DEBUG "Appending ${expanded_file} to ${PUP_CORE_FILES_LIST}")
        LIST(APPEND ${PUP_CORE_FILES_LIST} ${expanded_file})
      endif()

    endif()
  endforeach()

  # cleanup
  unset(expanded_file)
  unset(match_gen)
  unset(var_name)
  unset(match_interface)
endmacro()


## Run code generators for a specific fidl file and transport library
## This code will create the following variables in the form:
##  {PREFIX}_{CORE/TRANSPORT}_{PROXY/STUB/COMMON/SKELETON}_DIR
## And create custom targets to generate the code into OUTPUT_DIR
##
## Example usage:
##
## SET_UP_GEN_FILES(
##   FIDL_FILE  ${CMAKE_SOURCE_DIR}/fidl/HelloWorld.fidl
##   OUTPUT_DIR ${GEN_OUTPUT_DIR}
##   VAR_PREFIX "HW"
##   VERSION 1
##   INTERFACES commonAPI.HelloWorld
##   MIDDLEWARE DBus
## )
##
## If MIDDLEWARE is omitted, it'll attempt to set the MIDDLEWARE from the cache
## variable CAPI_MIDDLEWARE, if that still does not exist, then the function will
## fail with an error
##
## Multiple Interfaces
##
## SET_UP_GEN_FILES(
##   FIDL_FILE  ${CMAKE_SOURCE_DIR}/fidl/HelloWorld.fidl
##   FDEPL_FILE ${CMAKE_SOURCE_DIR}/fidl/HelloWorld.fdepl
##   OUTPUT_DIR ${GEN_OUTPUT_DIR}
##   TOP_PREFIX "FD"
##   VAR_PREFIXES "HW" "TI"
##   VERSIONS 1 2
##   INTERFACES
##     test.HelloWorld
##     test.TestInterface
## )
##
## Additional options
## - DO_CORE_RERUN_WITH_FDEPL:
##     Removed
## - ADDITIONAL_OUTPUTS
##     List of additional files that will be generated.  All generated files
##     that are to be linked against need to be listed here or else CMake will
##     see them as missing and report an error.
## - NO_CLOBBER
##     Intended for debugging.  With this option the generators won't be re-run
##     if the generated files exist - allowing user changes to persist.  When using
##     this option it is recommended to generate code into the source directory rather
##     than the build directory, otherwise system builders like FSB will clobber the
##     generated code anyways.
macro(SET_UP_GEN_FILES)
  set(options DO_CORE_RERUN_WITH_FDEPL NO_CLOBBER)
  set(oneValueArgs OUTPUT_DIR INSTALL_HEADERS_DIR FIDL_FILE FDEPL_FILE VAR_PREFIX VERSION MIDDLEWARE TOP_PREFIX)
  set(multiValueArgs VAR_PREFIXES VERSIONS INTERFACES ADDITIONAL_OUTPUTS)
  cmake_parse_arguments(
    SUGF "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN}
  )

  list(LENGTH SUGF_VAR_PREFIXES n_sugf_var_prefixes)
  list(LENGTH SUGF_VERSIONS n_sugf_versions)
  list(LENGTH SUGF_INTERFACES n_sugf_interfaces)

  if(${SUGF_DO_CORE_RERUN_WITH_FDEPL})
    message(WARNING "DO_CORE_RERUN_WITH_FDEPL is deprecated, please remove it from your call to SET_UP_GEN_FILES")
  endif()

  if((NOT DEFINED SUGF_VAR_PREFIX) AND ("${n_sugf_var_prefixes}" EQUAL 0))
    message(FATAL_ERROR "Must specify either 'VAR_PREFIX' or 'VAR_PREFIXES'")
  endif()
  if(DEFINED SUGF_VAR_PREFIX AND DEFINED SUGF_VAR_PREFIXES)
    message(FATAL_ERROR "'VAR_PREFIX' and 'VAR_PREFIXES' are mutually exclusive options")
  endif()
  if(DEFINED SUGF_VAR_PREFIX)
    # Backwards compatibility
    set(SUGF_VAR_PREFIXES ${SUGF_VAR_PREFIX})
    set(n_sugf_var_prefixes 1)
    unset(SUGF_VAR_PREFIX)
  endif()
  if("${n_sugf_var_prefixes}" GREATER_EQUAL 1)
    list(LENGTH SUGF_VAR_PREFIXES n_sugf_var_prefixes)
    if(NOT ${n_sugf_interfaces} EQUAL ${n_sugf_var_prefixes})
      message(FATAL_ERROR "The number of 'VAR_PREFIXES' (${n_sugf_var_prefixes}) provided must match the number of 'INTERFACES' (${n_sugf_interfaces})")
    endif()
  endif()

  if(NOT DEFINED SUGF_TOP_PREFIX)
    if(${n_sugf_var_prefixes} EQUAL 1)
      # Backwards compatibility
      list(GET SUGF_VAR_PREFIXES 0 SUGF_TOP_PREFIX)
    else()
      set(SUGF_TOP_PREFIX "FD")
    endif()
  endif()

  if((NOT DEFINED SUGF_VERSION) AND ("${n_sugf_versions}" EQUAL 0))
    message(FATAL_ERROR "Must specify either 'VERSION' or 'VERSIONS'")
  endif()
  if(DEFINED SUGF_VERSION AND DEFINED SUGF_VERSIONS)
    message(FATAL_ERROR "'VERSION' and 'VERSIONS' are mutually exclusive options")
  endif()
  if(DEFINED SUGF_VERSION)
    # Backwards compatibility
    foreach(i RANGE 1 ${n_sugf_interfaces})
      list(APPEND SUGF_VERSIONS ${SUGF_VERSION})
    endforeach()
    list(LENGTH SUGF_VERSIONS n_sugf_versions)
    unset(SUGF_VERSION)
  endif()
  if(NOT (${n_sugf_interfaces} EQUAL ${n_sugf_versions}))
    message(FATAL_ERROR "The number of 'VERSIONS' (${n_sugf_versions}) provided must match the number of 'INTERFACES' (${n_sugf_interfaces})")
  endif()

  if (${SUGF_NO_CLOBBER})
    string(FIND ${SUGF_OUTPUT_DIR} ${CMAKE_SOURCE_DIR} SUGF_OUTPUT_DIR_IN_GEN_DIR)
    if (SUGF_OUTPUT_DIR_IN_GEN_DIR)
      message(WARNING "NO_CLOBBER was selected, however the output for CommonAPI code is outside of the source directory.  In FSB this will result in clobbering")
    endif()
  endif()

  # Cleanup
  unset(n_sugf_var_prefixes)
  unset(n_sugf_versions)
  unset(n_sugf_interfaces)


  list(APPEND CMAKE_MESSAGE_CONTEXT "capi.gen")

  if(NOT SUGF_MIDDLEWARE)
    # CAPI_MIDDLEWARE is a frequently a cache variable used to set this
    if(CAPI_MIDDLEWARE)
      set(SUGF_MIDDLEWARE ${CAPI_MIDDLEWARE})
    else()
      message(FATAL_ERROR "Cannot continue, please specify middleware transport with MIDDLEWARE parameter or set the CAPI_MIDDLEWARE cache variable")
    endif()
  endif()

  if(${SUGF_MIDDLEWARE} STREQUAL "SomeIP")
    if(NOT SUGF_FDEPL_FILE)
      message(FATAL_ERROR "No FDEPL file specified, an FDEPL is required for ${SUGF_MIDDLEWARE}")
    endif()

    message(DEBUG "For ${SUGF_MIDDLEWARE}, using the fdepl for all generators")
    set(SUGF_FIDL_FILE ${SUGF_FDEPL_FILE})
  else()
    if(NOT SUGF_FIDL_FILE)
      message(FATAL_ERROR "No FIDL file specified")
    endif()
  endif()

  # set(core directory hierarchy)
  set("${SUGF_TOP_PREFIX}_CORE_BASE_DIR"     "${SUGF_OUTPUT_DIR}/core")
  set("${SUGF_TOP_PREFIX}_CORE_COMMON_DIR"   "${${SUGF_TOP_PREFIX}_CORE_BASE_DIR}/common")
  set("${SUGF_TOP_PREFIX}_CORE_PROXY_DIR"    "${${SUGF_TOP_PREFIX}_CORE_BASE_DIR}/proxy")
  set("${SUGF_TOP_PREFIX}_CORE_STUB_DIR"     "${${SUGF_TOP_PREFIX}_CORE_BASE_DIR}/stub")
  set("${SUGF_TOP_PREFIX}_CORE_SKELETON_DIR" "${${SUGF_TOP_PREFIX}_CORE_BASE_DIR}/skeleton")

  # set(SomeIP/DBus directory hierarchy)
  if(${SUGF_MIDDLEWARE} STREQUAL "DBus")
    set("${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR"   "${SUGF_OUTPUT_DIR}/dbus")
  elseif(${SUGF_MIDDLEWARE} STREQUAL "SomeIP")
    set("${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR"   "${SUGF_OUTPUT_DIR}/someip")
  else()
    set("${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR"   "${SUGF_OUTPUT_DIR}/soa")
  endif()
  set("${SUGF_TOP_PREFIX}_TRANSPORT_COMMON_DIR"   "${${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR}/common")
  set("${SUGF_TOP_PREFIX}_TRANSPORT_PROXY_DIR"    "${${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR}/proxy")
  set("${SUGF_TOP_PREFIX}_TRANSPORT_STUB_DIR"     "${${SUGF_TOP_PREFIX}_TRANSPORT_BASE_DIR}/stub")

  # Include directories
  set(${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS
    ${${SUGF_TOP_PREFIX}_CORE_COMMON_DIR}
    ${${SUGF_TOP_PREFIX}_CORE_PROXY_DIR}
    ${${SUGF_TOP_PREFIX}_CORE_STUB_DIR}
    ${${SUGF_TOP_PREFIX}_CORE_SKELETON_DIR}

    ${${SUGF_TOP_PREFIX}_TRANSPORT_COMMON_DIR}
    ${${SUGF_TOP_PREFIX}_TRANSPORT_PROXY_DIR}
    ${${SUGF_TOP_PREFIX}_TRANSPORT_STUB_DIR}
  )

  LIST_MESSAGE(LEVEL VERBOSE HEADER "${PROJECT_NAME} capi generated include directories:" ITEMS "${${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS}")

  set(${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES)
  set(${SUGF_TOP_PREFIX}_CAPI_GEN_${SUGF_MIDDLEWARE}_FILES)
  foreach(int_name IN LISTS SUGF_INTERFACES)

    list(POP_FRONT SUGF_VERSIONS INT_VERSION)
    list(POP_FRONT SUGF_VAR_PREFIXES INT_VAR_PREFIX)

    # Split the interface into package/interface
    SEP_PACKAGE(FULL_PACKAGE ${int_name} OUTPUT_PREFIX SP)

    # Create paths with the package for easier inclusion
    set(${INT_VAR_PREFIX}_CORE_COMMON_PKG_DIR        ${${SUGF_TOP_PREFIX}_CORE_COMMON_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_CORE_PROXY_PKG_DIR         ${${SUGF_TOP_PREFIX}_CORE_PROXY_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_CORE_SKELETON_PKG_DIR      ${${SUGF_TOP_PREFIX}_CORE_SKELETON_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_CORE_STUB_PKG_DIR          ${${SUGF_TOP_PREFIX}_CORE_STUB_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})

    set(${INT_VAR_PREFIX}_TRANSPORT_COMMON_PKG_DIR   ${${SUGF_TOP_PREFIX}_TRANSPORT_COMMON_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_TRANSPORT_PROXY_PKG_DIR    ${${SUGF_TOP_PREFIX}_TRANSPORT_PROXY_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_TRANSPORT_SKELETON_PKG_DIR ${${SUGF_TOP_PREFIX}_TRANSPORT_SKELETON_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})
    set(${INT_VAR_PREFIX}_TRANSPORT_STUB_PKG_DIR     ${${SUGF_TOP_PREFIX}_TRANSPORT_STUB_DIR}/v${INT_VERSION}/${SP_PACKAGE_PATH})

    # Core
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES" ${${INT_VAR_PREFIX}_CORE_COMMON_PKG_DIR}/${SP_INTERFACE}.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES" ${${INT_VAR_PREFIX}_CORE_PROXY_PKG_DIR}/${SP_INTERFACE}Proxy.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES" ${${INT_VAR_PREFIX}_CORE_PROXY_PKG_DIR}/${SP_INTERFACE}ProxyBase.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES" ${${INT_VAR_PREFIX}_CORE_SKELETON_PKG_DIR}/${SP_INTERFACE}StubDefault.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES" ${${INT_VAR_PREFIX}_CORE_STUB_PKG_DIR}/${SP_INTERFACE}Stub.hpp)

    # Middlewear Transport Layer
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_COMMON_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}Deployment.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_COMMON_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}Deployment.cpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_PROXY_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}Proxy.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_PROXY_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}Proxy.cpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_STUB_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}StubAdapter.hpp)
    list(APPEND "${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES" ${${INT_VAR_PREFIX}_TRANSPORT_STUB_PKG_DIR}/${SP_INTERFACE}${SUGF_MIDDLEWARE}StubAdapter.cpp)

    # Add the specified ADDITIONAL_OUTPUTS
    PROCESS_USER_PATHS(
      CORE_FILES_LIST      ${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES
      TRANSPORT_FILES_LIST ${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES
      INTERFACE ${INT_VAR_PREFIX}
      USER_PATHS ${SUGF_ADDITIONAL_OUTPUTS}
    )

    list(APPEND ${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES      ${${INT_VAR_PREFIX}_CAPI_GEN_CORE_FILES})
    list(APPEND ${SUGF_TOP_PREFIX}_CAPI_GEN_TRANSPORT_FILES ${${INT_VAR_PREFIX}_CAPI_GEN_TRANSPORT_FILES})

    # Output some helpful messages to the consumer to use these directories
    set(int_dirs
      ${INT_VAR_PREFIX}_CORE_COMMON_PKG_DIR
      ${INT_VAR_PREFIX}_CORE_PROXY_PKG_DIR
      ${INT_VAR_PREFIX}_CORE_SKELETON_PKG_DIR
      ${INT_VAR_PREFIX}_CORE_STUB_PKG_DIR

      ${INT_VAR_PREFIX}_TRANSPORT_COMMON_PKG_DIR
      ${INT_VAR_PREFIX}_TRANSPORT_PROXY_PKG_DIR
      ${INT_VAR_PREFIX}_TRANSPORT_SKELETON_PKG_DIR
      ${INT_VAR_PREFIX}_TRANSPORT_STUB_PKG_DIR
    )
    LIST_MESSAGE(LEVEL VERBOSE HEADER "Defined variables for interface ${int_name} directories: " ITEMS ${int_dirs})
    unset(int_dirs)

  endforeach()
  list(REMOVE_DUPLICATES ${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS)
  list(REMOVE_DUPLICATES ${SUGF_TOP_PREFIX}_CAPI_GEN_TRANSPORT_FILES)
  list(REMOVE_DUPLICATES ${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES)

  if(SUGF_INSTALL_HEADERS_DIR)
    message(VERBOSE "Modifying include directories to include build and install interfaces")
    # We're going to do an install, use build and install generator expressions
    set(GEN_EXP_INCUDE_DIRS)
    foreach(abs_dir IN LISTS ${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS)
      string(REPLACE ${SUGF_OUTPUT_DIR}/ "" rel_dir ${abs_dir})
      list(APPEND GEN_EXP_INCLUDE_DIRS $<BUILD_INTERFACE:${SUGF_OUTPUT_DIR}/${rel_dir}>)
      list(APPEND GEN_EXP_INCLUDE_DIRS $<INSTALL_INTERFACE:${SUGF_INSTALL_HEADERS_DIR}/${rel_dir}>)
      unset(rel_dir)
    endforeach()
    set(${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS ${GEN_EXP_INCLUDE_DIRS})
    unset(GEN_EXP_INCUDE_DIRS)
  endif()
  LIST_MESSAGE(LEVEL VERBOSE HEADER "Providing an \"all\" include directory variable ${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS containing the directories: " ITEMS ${${SUGF_TOP_PREFIX}_CAPI_INCLUDE_DIRS})

  # Check the first output file, if it exists and NO_CLOBBER is specified, do not setup the generators
  list(GET ${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES 0 FIRST_GENERATED_FILE)
  if (NOT EXISTS ${FIRST_GENERATED_FILE} OR NOT ${SUGF_NO_CLOBBER})

    if(TARGET CommonAPI::Core::gen)
      LIST_MESSAGE(LEVEL VERBOSE HEADER "Create target for core files:" ITEMS "${${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES}")
      add_custom_command(
        COMMAND CommonAPI::Core::gen
          --dest-common="${${SUGF_TOP_PREFIX}_CORE_COMMON_DIR}"
          --dest-proxy="${${SUGF_TOP_PREFIX}_CORE_PROXY_DIR}"
          --dest-stub="${${SUGF_TOP_PREFIX}_CORE_STUB_DIR}"
          --dest-skel="${${SUGF_TOP_PREFIX}_CORE_SKELETON_DIR}"
          -sk
          "${SUGF_FIDL_FILE}"
        DEPENDS ${SUGF_FIDL_FILE}
        OUTPUT  ${${SUGF_TOP_PREFIX}_CAPI_GEN_CORE_FILES}
        COMMENT "Generating CAPI core code for ${SUGF_FIDL_FILE}"
      )
    else()
      message(WARNING "Core generator for CommonAPI core was not configured, cannot create dependency graph for core generated files")
    endif()

    if(TARGET CommonAPI::${SUGF_MIDDLEWARE}::gen)
      LIST_MESSAGE(LEVEL VERBOSE HEADER "Create target for middleware transport files:" ITEMS "${${SUGF_TOP_PREFIX}_CAPI_GEN_TRANSPORT_FILES}")
      add_custom_command(
        COMMAND CommonAPI::${SUGF_MIDDLEWARE}::gen
          --dest-common="${${SUGF_TOP_PREFIX}_TRANSPORT_COMMON_DIR}"
          --dest-proxy="${${SUGF_TOP_PREFIX}_TRANSPORT_PROXY_DIR}"
          --dest-stub="${${SUGF_TOP_PREFIX}_TRANSPORT_STUB_DIR}"
          "${SUGF_FDEPL_FILE}"
        DEPENDS ${SUGF_FDEPL_FILE}
        OUTPUT  ${${SUGF_TOP_PREFIX}_CAPI_GEN_TRANSPORT_FILES}
        COMMENT "Generating CAPI ${SUGF_MIDDLEWARE} binding code for ${SUGF_FIDL_FILE}"
      )
    else()
      message(WARNING "Middleware generator for ${SUGF_MIDDLEWARE} was not configured, cannot create dependency graph for transport generated files")
    endif()

  else()
    message(STATUS "Skipping generation of CAPI files because the first generated file ${FIRST_GENERATED_FILE} exists and NO_CLOBBER is specified")
  endif()
endmacro()

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
