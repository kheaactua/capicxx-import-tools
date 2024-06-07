if(CommonAPIImporter_FOUND)
  return()
endif()

include(FindPackageHandleStandardArgs)

if(NOT DEFINED CommonAPIImporter_FIND_VERSION_MAJOR)
  set(CommonAPIImporter_FIND_VERSION_MAJOR 3)
endif()
if(NOT DEFINED CommonAPIImporter_FIND_VERSION_MINOR)
  set(CommonAPIImporter_FIND_VERSION_MINOR 2)
endif()
if(NOT DEFINED CommonAPIImporter_FIND_VERSION_PATCH)
  set(CommonAPIImporter_FIND_VERSION_PATCH 3)
endif()

set(test_CommonAPIImporter_FIND_VERSION ${CommonAPIImporter_FIND_VERSION_MAJOR}.${CommonAPIImporter_FIND_VERSION_MINOR})
if(DEFINED CommonAPIImporter_FIND_VERSION_PATCH)
  set(test_CommonAPIImporter_FIND_VERSION ${CommonAPIImporter_FIND_VERSION_MAJOR}.${CommonAPIImporter_FIND_VERSION_MINOR}.${CommonAPIImporter_FIND_VERSION_PATCH})
endif()

set(CommonAPIImporter_FIND_VERSION ${test_CommonAPIImporter_FIND_VERSION} CACHE STRING "CommonAPI Version")

# Default to same version
set(CommonAPI_Core_FIND_VERSION ${CommonAPIImporter_FIND_VERSION} CACHE STRING "CommonAPI Core Version")
set(CommonAPI_SomeIP_FIND_VERSION ${CommonAPIImporter_FIND_VERSION} CACHE STRING "CommonAPI SomeIP Version")
set(CommonAPI_DBus_FIND_VERSION ${CommonAPIImporter_FIND_VERSION} CACHE STRING "CommonAPI DBus Version")

# List to collect the required variables (set by the includes)
set(COMMON_API_COMPONENT_REQUIRED_VARS)

#
# Validate the list of requested components.
# Like most user validation code, it's pretty ugly, but it does provide a
# cleaner COMPONENTS list, as well as provide the vapability of having a
# "virtual" gen target which is properly replaced with the selected middleware
# and core generatores.

# Convert the components to lower case
set(_components)
foreach(c IN ITEMS ${CommonAPIImporter_FIND_COMPONENTS})
  string(TOLOWER ${c} component)
  list(APPEND _components ${component})
endforeach()

# Check which are in the list, if only one treat that as a selected middleware,
# if core isn't specified then add it
list(FIND _components core _core_requested)
list(FIND _components dbus _dbus_requested)
list(FIND _components someip _someip_requested)
if( ((_dbus_requested GREATER -1) OR (_someip_requested GREATER -1)) AND (NOT _core_requested GREATER -1))
  message(WARNING "Middleware runtime was requested but Core was ommited, adding Core to requested components")
  list(APPEND _components core)
endif()

if(_dbus_requested GREATER -1)
  set(_SELECTED_MIDDLEWARE DBus)
  set(_dbus_requested 1)
elseif(_someip_requested GREATER -1)
  set(_SELECTED_MIDDLEWARE SomeIP)
  set(_someip_requested 1)
endif()

math(EXPR _component_check "${_dbus_requested} + ${_someip_requested}")
if(_component_check GREATER 1)
  message(WARNING "Multiple middlewares were selected, disabling configuration of general ::Transport targets")
  set(_SELECTED_MIDDLEWARE)
endif()


# Allow a virtual component named "gen" if a middleware is selected.  Then
# remove "gen' from the list
list(FIND _components gen _gen_requested)
if((_gen_requested GREATER -1) AND _SELECTED_MIDDLEWARE)
  message(STATUS "Provided virtual component 'gen' with ${_SELECTED_MIDDLEWARE}-gen")
  if(_dbus_requested GREATER -1)
    list(APPEND _components dbus-gen core-gen)
  elseif(_someip_requested GREATER -1)
    list(APPEND _components someip-gen core-gen)
  endif()
endif()
list(REMOVE_DUPLICATES _components)
list(REMOVE_ITEM _components gen)
list(FIND _components core-gen _core-gen_requested)
list(FIND _components dbus-gen _dbus-gen_requested)
list(FIND _components someip-gen _someip-gen_requested)
if((_dbus-gen_requested OR _someip-gen_requested) AND NOT _core-gen_requested)
  message(WARNING "Middleware generator was requested but Core generator was ommited, adding Core generator to requested components")
  list(APPEND _components core-gen)
endif()

#
# Find our components

foreach(component IN ITEMS ${_components})
  if(component STREQUAL "core")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/Core.cmake)
    add_library(CommonAPI::Core ALIAS common_api_core)
  elseif(component STREQUAL "core-gen")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/Core-gen.cmake)
    if(NOT TARGET CommonAPI::Core::gen)
      message(VERBOSE "Aliasing gen_capi target for core components")
      add_executable(CommonAPI::Core::gen ALIAS common_api_core_gen)
    endif()

  elseif(component STREQUAL "dbus")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/DBus.cmake)
    add_library(CommonAPI::DBus ALIAS common_api_dbus)

  elseif(component STREQUAL "dbus-gen")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/DBus-gen.cmake)
    if(NOT TARGET CommonAPI::DBus::gen)
      # Normally this target shouldn't be explicitly called, but adding it just
      # in case someone needs it
      message(VERBOSE "Creating gen_capi_DBus target for DBus middleware")
      add_executable(CommonAPI::DBus::gen IMPORTED GLOBAL)
      set_property(TARGET CommonAPI::DBus::gen PROPERTY IMPORTED_LOCATION ${CAPI_DBus_GEN})
    endif()

  elseif(component STREQUAL "someip")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/SomeIP.cmake)
    add_library(CommonAPI::SomeIP ALIAS common_api_someip)

  elseif(component STREQUAL "someip-gen")
    include(${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/SomeIP-gen.cmake)
    if(NOT TARGET CommonAPI::SomeIP::gen)
      # Normally this target shouldn't be explicitly called, but adding it just
      # in case someone needs it
      message(VERBOSE "Aliasing gen_capi_SomeIP target for SOME/IP middleware")
      add_executable(CommonAPI::SomeIP::gen ALIAS common_api_someip_gen)
    endif()

  else()
    message(FATAL_ERROR "Unknown component ${component}")
  endif()
endforeach()

#
# Assert that we found everything we need
if (COMMON_API_COMPONENT_REQUIRED_VARS)
  find_package_handle_standard_args(CommonAPIImporter
    REQUIRED_VARS ${COMMON_API_COMPONENT_REQUIRED_VARS}
    VERSION_VAR CommonAPIImporter_VERSION
  )
endif()

#
# Provide the path to CAPI CMake tools that can handle file generation

set(CAPI_GENERATE_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/CommonAPIImporter_impl/GenerateCapiCode.cmake" CACHE PATH "CAPI CMake Generator Helper")

#
# Set up a ::Transport target to abstract the transport choice

if(NOT TARGET common_api_middleware)
  if(_SELECTED_MIDDLEWARE)
    if(_SELECTED_MIDDLEWARE STREQUAL "DBus" OR _SELECTED_MIDDLEWARE STREQUAL "SomeIP")
      # Create an interface for our chosen middleware "lib"
      add_library(common_api_middleware INTERFACE IMPORTED)
      if(_SELECTED_MIDDLEWARE STREQUAL "DBus")
        target_link_libraries(common_api_middleware INTERFACE CommonAPI::DBus)
      else()
        target_link_libraries(common_api_middleware INTERFACE CommonAPI::SomeIP)
      endif()
      message(STATUS "Configured CommonAPI::Transport interface target for ${_SELECTED_MIDDLEWARE}")
      add_library(CommonAPI::Transport ALIAS common_api_middleware)
    else()
      message(FATAL_ERROR "Unknown transport/middleware \"${_SELECTED_MIDDLEWARE}\"")
    endif()
  endif()

  find_package(Threads)

  # Setup a "combined" target
  add_library(common_api_combined INTERFACE IMPORTED)
  target_link_libraries(common_api_combined
    INTERFACE
      CommonAPI::Transport
      CommonAPI::Core
      Threads::Threads
  )
  add_library(CommonAPI::Combined ALIAS common_api_combined)
endif()


#
# Define generator targets

if(_SELECTED_MIDDLEWARE)
  add_executable(CommonAPI::Transport::gen IMPORTED)
  set_property(TARGET CommonAPI::Transport::gen PROPERTY IMPORTED_LOCATION ${CAPI_${_SELECTED_MIDDLEWARE}_GEN})
endif()

set(CommonAPIImporter_FOUND TRUE)

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
