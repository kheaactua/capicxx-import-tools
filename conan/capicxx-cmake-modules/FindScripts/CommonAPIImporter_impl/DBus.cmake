find_package(CommonAPI-DBus ${CommonAPI_DBus_FIND_VERSION} REQUIRED)

find_library(CommonAPI_DBus_LIBRARY
  NAMES CommonAPI-DBus
  PATHS
    # Found in sysroot: package capicxx-dbus-runtime
    /usr/lib

    # Attempting to build locally
    /usr/local/lib
)

if(NOT DBus1_FOUND)
  find_package(DBus1)
endif()

# Normalise variables (buildroot has symlinks which can cause some problems here)
foreach(var IN ITEMS COMMONAPI_DBUS_INCLUDE_DIRS CommonAPI_DBus_LIBRARY DBus1_INCLUDE_DIRS DBus1_LIBRARY)
  get_filename_component(${var} "${${var}}" ABSOLUTE)
endforeach()

mark_as_advanced(COMMONAPI_DBUS_INCLUDE_DIRS COMMONAPI_DBUS_VERSION CommonAPI_DBus_LIBRARY)

list(APPEND COMMON_API_COMPONENT_REQUIRED_VARS
  COMMONAPI_DBUS_INCLUDE_DIRS
  CommonAPI_DBus_LIBRARY
)

if(NOT TARGET common_api_dbus)
  add_library(common_api_dbus INTERFACE)
  target_include_directories(common_api_dbus SYSTEM INTERFACE ${COMMONAPI_DBUS_INCLUDE_DIRS})
  target_link_libraries(common_api_dbus INTERFACE
    ${CommonAPI_DBus_LIBRARY}
    dbus-1
  )

  message(STATUS "Found middleware transport component CommonAPI::DBus
   inc:
     - ${COMMONAPI_DBUS_INCLUDE_DIRS}
     - ${DBus1_INCLUDE_DIRS}
   lib:
     - ${CommonAPI_DBus_LIBRARY}
     - ${DBus1_LIBRARY}")
endif()

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
