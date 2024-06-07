cmake_minimum_required(VERSION 3.23)
project(capicxx-cmake-modules VERSION 1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME capicxx-cmake-modules)

install(
  DIRECTORY ${PROJECT_SOURCE_DIR}/FindScripts/
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
  COMPONENT capicxx-cmake-modules
  FILES_MATCHING PATTERN "*.cmake"
)

#  vim: set ts=2 sw=2 tw=0 et :
