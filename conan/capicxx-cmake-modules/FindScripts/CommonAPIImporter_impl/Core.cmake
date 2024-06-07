find_package(CommonAPI ${CommonAPI_Core_FIND_VERSION} EXACT REQUIRED
  CONFIG
  NO_CMAKE_PACKAGE_REGISTRY
  NO_SYSTEM_ENVIRONMENT_PATH
)

# Use the lib imported from the CommonAPI package
get_target_property(CommonAPI_Core_LIBRARY CommonAPI LOCATION)

if(NOT TARGET common_api_core)
  add_library(common_api_core INTERFACE IMPORTED)
  target_link_libraries(common_api_core INTERFACE
    CommonAPI
  )

  add_library(common_api_core-static INTERFACE IMPORTED)
  target_link_libraries(common_api_core-static INTERFACE
    CommonAPI-static
  )

  # Emit a message showing where the CommonAPI target gets its include and libs.
  get_property(COMMONAPI_INCLUDE_DIRS TARGET CommonAPI PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
  get_property(CommonAPI_Core_LIBRARY TARGET CommonAPI PROPERTY LOCATION)
  message(STATUS "Found runtime CommonAPI::Core
   inc: ${COMMONAPI_INCLUDE_DIRS}
   lib: ${CommonAPI_Core_LIBRARY}")
endif()

# vim: ts=2 sw=2 sts=0 expandtab ff=unix :
