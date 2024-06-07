cmake_policy(SET CMP0048 NEW)
cmake_minimum_required(VERSION 3.25)
project(capi-generators VERSION 0.1)

find_program(CAPI_CORE_GEN
  NAMES
    commonapi-core-generator-linux-x86_64
  PATHS
    ${PROJECT_SOURCE_DIR}/core
  REQUIRED
  NO_DEFAULT_PATH
  NO_CMAKE_PATH
  NO_CMAKE_ENVIRONMENT_PATH
  NO_SYSTEM_ENVIRONMENT_PATH
  NO_CMAKE_SYSTEM_PATH
)
add_executable(capi-core-gen IMPORTED ${CAPI_CORE_GEN})
set_target_properties(capi-core-gen PROPERTIES IMPORTED_LOCATION ${CAPI_CORE_GEN})

find_program(CAPI_SOMEIP_GEN
  NAMES
    commonapi-someip-generator-linux-x86_64
  PATHS
    ${PROJECT_SOURCE_DIR}/someip
  REQUIRED
  NO_DEFAULT_PATH
  NO_CMAKE_PATH
  NO_CMAKE_ENVIRONMENT_PATH
  NO_SYSTEM_ENVIRONMENT_PATH
  NO_CMAKE_SYSTEM_PATH
)
add_executable(capi-someip-gen IMPORTED GLOBAL)
set_target_properties(capi-someip-gen PROPERTIES IMPORTED_LOCATION ${CAPI_SOMEIP_GEN})

include(GNUInstallDirs)
set(DEST_BIN_DIR "${CMAKE_INSTALL_BINDIR}/capi" CACHE PATH "Host bin directory")

install(
  DIRECTORY $<TARGET_FILE_DIR:capi-core-gen>
  DESTINATION "${DEST_BIN_DIR}"
  COMPONENT capicxx-core-tools
  MESSAGE_NEVER
)

install(
  PROGRAMS $<TARGET_FILE:capi-core-gen>
  DESTINATION "${DEST_BIN_DIR}/core"
  COMPONENT capicxx-core-tools
)

install(
  DIRECTORY $<TARGET_FILE_DIR:capi-someip-gen>
  DESTINATION "${DEST_BIN_DIR}"
  COMPONENT capicxx-someip-tools
  MESSAGE_NEVER
)

install(
  PROGRAMS $<TARGET_FILE:capi-someip-gen>
  DESTINATION "${DEST_BIN_DIR}/someip"
  COMPONENT capicxx-someip-tools
)

#
# Create a package file.  Imported targets can't be exported, so we have to
# manually do this

include(CMakePackageConfigHelpers)

set(CAPI_INSTALL_REL_DIR "${DEST_BIN_DIR}")
set(CAPI_INSTALL_DIR "${DEST_BIN_DIR}")

configure_package_config_file(CapiGeneratorConfig.cmake.in CapiGeneratorConfig.cmake
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
  PATH_VARS
    CAPI_INSTALL_REL_DIR
    CAPI_INSTALL_DIR
)

install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/CapiGeneratorConfig.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

#  vim: set ts=2 sw=2 tw=0 et :
